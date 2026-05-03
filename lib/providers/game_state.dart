import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/engine/camera.dart';
import 'package:farm_fintech/engine/isometric_engine.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/models/tile.dart';
import 'package:farm_fintech/models/weather_event.dart';
import 'package:farm_fintech/models/financial/bnpl_plan.dart';
import 'package:farm_fintech/models/financial/loan.dart';
import 'package:farm_fintech/models/financial/insurance.dart';
import 'package:farm_fintech/services/cloud_functions_service.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/services/weather_service.dart';

/// Central game state managed via [ChangeNotifier].
class GameState extends ChangeNotifier {
  final IsometricEngine engine = const IsometricEngine();
  final GameCamera camera = GameCamera();
  final CloudFunctionsService _cloud = CloudFunctionsService();
  final WeatherService _weather = WeatherService();
  final FirestoreService _firestore = FirestoreService();
  final Random _random = Random();

  // ── Player ──────────────────────────────────────────────────
  Player? player;

  // ── Grid ────────────────────────────────────────────────────
  late List<List<Tile>> grid;

  // ── Selection ───────────────────────────────────────────────
  (int, int)? selectedTile;

  // ── Weather ─────────────────────────────────────────────────
  DisasterType activeDisaster = DisasterType.none;

  // ── Financial ───────────────────────────────────────────────
  List<BnplPlan> bnplPlans = [];
  StreamSubscription<List<BnplPlan>>? _bnplPlansSub;
  StreamSubscription<List<Map<String, dynamic>>>? _txSub;
  List<Loan> loans = [];
  List<Insurance> insurances = [];

  // ── Game Day ────────────────────────────────────────────────
  int currentDay = 1;
  int _remainingCycleSeconds = kGameDayDurationMinutes * 60;
  int _manualNextDayUsedToday = 0;
  DateTime _manualNextDayUsageDate = DateTime.now();
  Timer? _dayCycleTimer;
  Timer? _loanSharkThreatTimer;
  bool _isAdvancingDay = false;
  int _loanSharkThreatSecondsRemaining = 0;
  final Map<String, double> _monthlyExpenses = {
    'seed': 0,
    'interest': 0,
    'insurance': 0,
    'equipment': 0,
    'nextDayFee': 0,
  };
  double _monthlyIncome = 0;
  MonthlyPnLReport? _pendingMonthlyReport;

  // ── Crop selection for planting ─────────────────────────────
  CropType? selectedCropToPlant;

  GameState() {
    _initGrid();
    _startDayCycleClock();
  }

  int get remainingCycleSeconds => _remainingCycleSeconds;
  bool get isDaytime => _remainingCycleSeconds > (kGameNightMinutes * 60);
  String get dayPhaseLabel => isDaytime ? 'Day' : 'Night';
  int get currentYear {
    final zeroBasedDay = (currentDay - 1).clamp(0, 1 << 30);
    final daysPerYear = kGameDaysPerMonth * kGameMonthsPerYear;
    return (zeroBasedDay ~/ daysPerYear) + 1;
  }

  int get currentMonth {
    final zeroBasedDay = (currentDay - 1).clamp(0, 1 << 30);
    final daysPerYear = kGameDaysPerMonth * kGameMonthsPerYear;
    final dayWithinYear = zeroBasedDay % daysPerYear;
    return (dayWithinYear ~/ kGameDaysPerMonth) + 1;
  }

  int get currentDayOfMonth {
    final zeroBasedDay = (currentDay - 1).clamp(0, 1 << 30);
    return (zeroBasedDay % kGameDaysPerMonth) + 1;
  }

  String get gameDateLabel =>
      'Y$currentYear M$currentMonth D$currentDayOfMonth';
  MonthlyPnLReport? get pendingMonthlyReport => _pendingMonthlyReport;
  bool get loanSharkThreatActive => _loanSharkThreatSecondsRemaining > 0;
  bool get tractorOwned => player?.tractorOwned ?? false;
  bool get autoHarvestEnabled => player?.autoHarvestEnabled ?? false;
  int get fertilizerPackCount => player?.fertilizerPackCount ?? 0;

  int get freeNextDayRemaining {
    _resetManualNextDayIfNewDate();
    return (kFreeManualNextDayPerRealDay - _manualNextDayUsedToday).clamp(
      0,
      kFreeManualNextDayPerRealDay,
    );
  }

  void _startDayCycleClock() {
    _dayCycleTimer?.cancel();
    _dayCycleTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isAdvancingDay) return;
      _remainingCycleSeconds--;
      if (_remainingCycleSeconds <= 0) {
        await _advanceDayCore(isManual: false);
        _remainingCycleSeconds = kGameDayDurationMinutes * 60;
      }
      notifyListeners();
    });
  }

  void _resetManualNextDayIfNewDate() {
    final nowDate = DateUtils.dateOnly(DateTime.now());
    final storedDate = DateUtils.dateOnly(_manualNextDayUsageDate);
    if (nowDate != storedDate) {
      _manualNextDayUsageDate = nowDate;
      _manualNextDayUsedToday = 0;
      if (player != null) {
        player!.manualNextDayUsedToday = 0;
        player!.manualNextDayUsageDate = nowDate;
      }
    }
  }

  bool _tryChargeManualNextDayFee() {
    if (player == null) return false;
    if (_manualNextDayUsedToday < kFreeManualNextDayPerRealDay) {
      _manualNextDayUsedToday++;
      return true;
    }

    final canPayCash = player!.cashBalance >= kManualNextDayCost;
    final canPayBank = player!.bankBalance >= kManualNextDayCost;
    if (!canPayCash && !canPayBank) return false;

    if (canPayCash) {
      player!.pay(kManualNextDayCost, method: PaymentMethod.cash);
    } else {
      player!.pay(kManualNextDayCost, method: PaymentMethod.bank);
    }
    _addMonthlyExpense('nextDayFee', kManualNextDayCost);
    _manualNextDayUsedToday++;

    // Update player object for persistence
    player!.manualNextDayUsedToday = _manualNextDayUsedToday;
    player!.manualNextDayUsageDate = _manualNextDayUsageDate;

    return true;
  }

  void _addMonthlyExpense(String category, double amount) {
    _monthlyExpenses[category] = (_monthlyExpenses[category] ?? 0) + amount;
  }

  void _addMonthlyIncome(double amount) {
    _monthlyIncome += amount;
  }

  void _startLoanSharkThreat({int seconds = 8}) {
    _loanSharkThreatSecondsRemaining = seconds;
    _loanSharkThreatTimer?.cancel();
    _loanSharkThreatTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _loanSharkThreatSecondsRemaining--;
      if (_loanSharkThreatSecondsRemaining <= 0) {
        _loanSharkThreatSecondsRemaining = 0;
        timer.cancel();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  Future<bool> takeLoanSharkLoan(double amount) async {
    if (player == null || amount <= 0) return false;

    final highInterestRate = 0.35; // 35% monthly (predatory)
    const termMonths = 3;
    final totalRepayment = amount * (1 + highInterestRate * termMonths);
    final monthlyPayment = totalRepayment / termMonths;

    final loan = Loan(
      id: 'shark-${DateTime.now().millisecondsSinceEpoch}',
      principal: amount,
      interestRate: highInterestRate,
      monthlyPayment: monthlyPayment,
      remainingBalance: totalRepayment,
    );

    loans.add(loan);
    player!.deposit(amount, method: PaymentMethod.cash);
    _startLoanSharkThreat();

    try {
      await _savePlayerState();
      await _saveGridState();
      notifyListeners();
      return true;
    } catch (_) {
      loans.removeWhere((l) => l.id == loan.id);
      player!.pay(amount, method: PaymentMethod.cash);
      return false;
    }
  }

  /// Set player and load their specific grid if it exists
  Future<void> setPlayer(Player newPlayer) async {
    player = newPlayer;
    // Sync state variables from persisted player object
    currentDay = newPlayer.currentDay;
    _manualNextDayUsedToday = newPlayer.manualNextDayUsedToday;
    _manualNextDayUsageDate = newPlayer.manualNextDayUsageDate;

    notifyListeners(); // Notify early so UI knows player/day is there

    final savedGrid = await _firestore.getGrid(newPlayer.uid);
    if (savedGrid != null) {
      grid = savedGrid;
    } else {
      _initGrid(); // Fallback to default
      await _saveGridState(); // Save the default grid
    }
    // Subscribe to realtime BNPL plan updates and recent transactions
    _bnplPlansSub?.cancel();
    _bnplPlansSub = _firestore.streamBnplPlans(newPlayer.uid).listen((plans) {
      bnplPlans = plans;
      notifyListeners();
    });

    _txSub?.cancel();
    _txSub = _firestore.streamTransactions(newPlayer.uid).listen((txs) {
      // Optionally process transactions for credit scoring or UI
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _saveGridState() async {
    if (player == null) return;
    await _firestore.saveGrid(player!.uid, grid);
  }

  void _processLoanSharkRepaymentsOnMonthEnd() {
    if (player == null) return;

    for (final loan in loans) {
      if (loan.status != LoanStatus.active || !loan.id.startsWith('shark-')) {
        continue;
      }

      final due = loan.monthlyPayment
          .clamp(0, loan.remainingBalance)
          .toDouble();
      if (due <= 0) {
        loan.status = LoanStatus.paid;
        continue;
      }

      var paid = false;
      if (player!.cashBalance >= due) {
        player!.pay(due, method: PaymentMethod.cash);
        paid = true;
      } else if (player!.bankBalance >= due) {
        player!.pay(due, method: PaymentMethod.bank);
        paid = true;
      }

      if (paid) {
        loan.remainingBalance -= due;
        _addMonthlyExpense('interest', due);
        if (loan.remainingBalance <= 0.01) {
          loan.remainingBalance = 0;
          loan.status = LoanStatus.paid;
        }
      } else {
        final intimidationPenalty = (due * 0.25).toDouble();
        loan.remainingBalance += intimidationPenalty;
        _addMonthlyExpense('interest', intimidationPenalty);
        _startLoanSharkThreat(seconds: 12);
      }
    }
  }

  void recordInsuranceExpense(double amount) {
    _addMonthlyExpense('insurance', amount);
    notifyListeners();
  }

  void acknowledgeMonthlyReport() {
    _pendingMonthlyReport = null;
    notifyListeners();
  }

  void _initGrid() {
    grid = List.generate(
      kGridRows,
      (row) => List.generate(kGridCols, (col) {
        // Place buildings in fixed positions
        if (col == 0 && row == 0) {
          return Tile(col: col, row: row, type: TileType.building);
        }
        if (col == 0 && row == 1) {
          return Tile(col: col, row: row, type: TileType.building);
        }
        // A pond
        if (col == 7 && row == 7) {
          return Tile(col: col, row: row, type: TileType.water);
        }
        // Starting farmland (3x3 area in center)
        if (col >= 3 && col <= 5 && row >= 3 && row <= 5) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        return Tile(col: col, row: row, type: TileType.grass);
      }),
    );
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _savePlayerState() async {
    if (player == null) return;
    await _firestore.savePlayer(player!);
  }

  /// Handle a tap on the isometric grid at screen position.
  void handleTap(Offset screenPos) {
    final worldPos = camera.screenToWorld(screenPos);
    final (col, row) = engine.screenToGrid(worldPos.dx, worldPos.dy);

    if (!engine.isValidTile(col, row)) {
      selectedTile = null;
      notifyListeners();
      return;
    }

    selectedTile = (col, row);
    notifyListeners();
  }

  /// Plant a crop on the selected tile.
  Future<bool> plantCrop(CropType cropType) async {
    if (selectedTile == null || player == null) return false;

    final (col, row) = selectedTile!;
    final tile = grid[row][col];
    final config = kCropConfig[cropType]!;
    final cost = config['seedCost'] as double;

    // Check balance
    if (player!.cashBalance < cost && player!.bankBalance < cost) {
      return false;
    }

    if (!tile.plant(cropType)) return false;

    tile.plantedDay = currentDay;

    final previousCashBalance = player!.cashBalance;
    final previousBankBalance = player!.bankBalance;

    // Deduct cost (prefer cash first)
    if (player!.cashBalance >= cost) {
      player!.pay(cost, method: PaymentMethod.cash);
    } else {
      player!.pay(cost, method: PaymentMethod.bank);
    }
    _addMonthlyExpense('seed', cost);

    try {
      await _savePlayerState();
      notifyListeners();
      return true;
    } catch (_) {
      tile.crop = null;
      tile.growthStage = 0;
      tile.plantedAt = null;
      player!.cashBalance = previousCashBalance;
      player!.bankBalance = previousBankBalance;
      _addMonthlyExpense('seed', -cost);
      return false;
    }
  }

  /// Harvest the selected tile's crop and add it to inventory.
  Future<CropType?> harvestCrop() async {
    if (selectedTile == null || player == null) return null;

    final (col, row) = selectedTile!;
    final tile = grid[row][col];
    final previousCrop = tile.crop;
    final previousGrowthStage = tile.growthStage;
    final previousPlantedAt = tile.plantedAt;
    final previousPlantedDay = tile.plantedDay;
    final harvested = tile.harvest();

    if (harvested == null) return null;

    final key = harvested.name;
    final previousQuantity = player!.inventory[key] ?? 0;
    player!.inventory[key] = previousQuantity + 1;

    try {
      await _savePlayerState();
      await _saveGridState();
      notifyListeners();
      return harvested;
    } catch (_) {
      tile.crop = previousCrop;
      tile.growthStage = previousGrowthStage;
      tile.plantedAt = previousPlantedAt;
      tile.plantedDay = previousPlantedDay;
      if (previousQuantity > 0) {
        player!.inventory[key] = previousQuantity;
      } else {
        player!.inventory.remove(key);
      }
      return null;
    }
  }

  /// Sell all inventory of a crop key and deposit revenue to cash wallet.
  Future<double?> sellInventoryCrop(String cropKey, {int? quantity}) async {
    if (player == null) return null;

    final availableQty = player!.inventory[cropKey] ?? 0;
    if (availableQty <= 0) return null;

    final qty = quantity ?? availableQty;
    if (qty <= 0 || qty > availableQty) return null;

    CropType? cropType;
    for (final value in CropType.values) {
      if (value.name == cropKey) {
        cropType = value;
        break;
      }
    }
    if (cropType == null) return null;

    final config = kCropConfig[cropType]!;
    final sellPrice = config['sellPrice'] as double;
    final revenue = sellPrice * qty;
    final previousCashBalance = player!.cashBalance;

    player!.deposit(revenue, method: PaymentMethod.cash);
    _addMonthlyIncome(revenue);
    final remainingQty = availableQty - qty;
    if (remainingQty > 0) {
      player!.inventory[cropKey] = remainingQty;
    } else {
      player!.inventory.remove(cropKey);
    }

    try {
      await _savePlayerState();
      notifyListeners();
      return revenue;
    } catch (_) {
      player!.cashBalance = previousCashBalance;
      player!.inventory[cropKey] = availableQty;
      _addMonthlyIncome(-revenue);
      return null;
    }
  }

  Future<bool> buyEquipment(double amount, PaymentMethod method) async {
    if (player == null) return false;

    final previousCashBalance = player!.cashBalance;
    final previousBankBalance = player!.bankBalance;
    final didPay = player!.pay(amount, method: method);
    if (!didPay) return false;
    _addMonthlyExpense('equipment', amount);

    try {
      await _savePlayerState();
      notifyListeners();
      return true;
    } catch (_) {
      player!.cashBalance = previousCashBalance;
      player!.bankBalance = previousBankBalance;
      _addMonthlyExpense('equipment', -amount);
      return false;
    }
  }

  Future<bool> unlockEquipment(String equipmentName) async {
    if (player == null) return false;

    final previousTractorOwned = player!.tractorOwned;
    final previousAutoHarvestEnabled = player!.autoHarvestEnabled;
    final previousFertilizerPackCount = player!.fertilizerPackCount;

    if (equipmentName == 'Tractor') {
      player!.tractorOwned = true;
      player!.autoHarvestEnabled = true;
    }

    if (equipmentName == 'Fertilizer Pack') {
      player!.fertilizerPackCount += 1;
    }

    try {
      await _savePlayerState();
      notifyListeners();
      return true;
    } catch (_) {
      player!.tractorOwned = previousTractorOwned;
      player!.autoHarvestEnabled = previousAutoHarvestEnabled;
      player!.fertilizerPackCount = previousFertilizerPackCount;
      return false;
    }
  }

  Future<int> useFertilizerPack() async {
    if (player == null || player!.fertilizerPackCount <= 0) return -1;

    final previousGrowthStages = <Tile, int>{};
    var boostedCount = 0;

    for (final row in grid) {
      for (final tile in row) {
        if (!tile.hasCrop || tile.growthStage >= 3) continue;
        previousGrowthStages[tile] = tile.growthStage;
        tile.growthStage = (tile.growthStage + 1).clamp(0, 3);
        boostedCount++;
      }
    }

    if (boostedCount == 0) {
      return 0;
    }

    final previousFertilizerPackCount = player!.fertilizerPackCount;
    player!.fertilizerPackCount -= 1;

    try {
      await _savePlayerState();
      notifyListeners();
      return boostedCount;
    } catch (_) {
      player!.fertilizerPackCount = previousFertilizerPackCount;
      previousGrowthStages.forEach((tile, growthStage) {
        tile.growthStage = growthStage;
      });
      return -1;
    }
  }

  Future<bool> setAutoHarvestEnabled(bool enabled) async {
    if (player == null || !player!.tractorOwned) return false;

    final previous = player!.autoHarvestEnabled;
    player!.autoHarvestEnabled = enabled;

    try {
      await _savePlayerState();
      notifyListeners();
      return true;
    } catch (_) {
      player!.autoHarvestEnabled = previous;
      return false;
    }
  }

  int _applyAutoHarvest() {
    if (!tractorOwned || !autoHarvestEnabled || player == null) return 0;

    var harvestedCount = 0;
    for (final row in grid) {
      for (final tile in row) {
        if (!tile.isHarvestable) continue;
        final harvested = tile.harvest();
        if (harvested == null) continue;

        final key = harvested.name;
        final current = player!.inventory[key] ?? 0;
        player!.inventory[key] = current + 1;
        harvestedCount++;
      }
    }
    return harvestedCount;
  }

  /// Advance the game by one day. Grows crops, checks BNPL dues via Cloud, etc.
  Future<bool> advanceDay() async {
    _resetManualNextDayIfNewDate();

    final previousCash = player?.cashBalance;
    final previousBank = player?.bankBalance;
    final previousUsed = _manualNextDayUsedToday;

    if (!_tryChargeManualNextDayFee()) {
      notifyListeners();
      return false;
    }

    try {
      await _savePlayerState();
    } catch (_) {
      if (player != null && previousCash != null && previousBank != null) {
        player!.cashBalance = previousCash;
        player!.bankBalance = previousBank;
      }
      _manualNextDayUsedToday = previousUsed;
      notifyListeners();
      return false;
    }

    return _advanceDayCore(isManual: true);
  }

  Future<bool> _advanceDayCore({required bool isManual}) async {
    if (_isAdvancingDay) return false;
    _isAdvancingDay = true;
    try {
      final previousYear = currentYear;
      final previousMonth = currentMonth;
      currentDay++;
      if (player != null) player!.currentDay = currentDay;

      if (isManual) {
        _remainingCycleSeconds = kGameDayDurationMinutes * 60;
      }

      // Grow crops based on in-game days
      for (final row in grid) {
        for (final tile in row) {
          if (tile.hasCrop && tile.growthStage < 3) {
            final config = kCropConfig[tile.crop!]!;
            final growthDays = config['growthDays'] as int;
            final daysSincePlant = tile.plantedDay != null
                ? currentDay - tile.plantedDay!
                : 0;

            // Simple growth: divide total growth time into 3 stages
            final stageInterval = growthDays ~/ 3;
            if (stageInterval > 0) {
              tile.growthStage = (daysSincePlant ~/ stageInterval).clamp(0, 3);
            } else {
              // If growth is less than 3 days, grow 1 stage per day
              tile.growthStage = daysSincePlant.clamp(0, 3);
            }
          }
        }
      }

      _applyAutoHarvest();

      notifyListeners();
      await _saveGridState(); // Persist crop growth
      await _savePlayerState(); // Persist currentDay change

      // Fire-and-forget server checks
      if (player != null) {
        var needsRefresh = false;
        var disasterTriggeredToday = false;

        // 1. Weather Check
        final weatherResult = await _weather.checkWeather(
          player!.gpsLat,
          player!.gpsLng,
        );
        if (weatherResult.hasDisaster && weatherResult.disasterType != null) {
          DisasterType type = DisasterType.none;
          // The Cloud Function returns string IDs like 'flood', 'storm', 'drought'
          if (weatherResult.disasterType == 'flood') {
            type = DisasterType.flood;
          }
          if (weatherResult.disasterType == 'storm') {
            type = DisasterType.storm;
          }
          if (weatherResult.disasterType == 'drought') {
            type = DisasterType.drought;
          }
          triggerDisaster(type);
          disasterTriggeredToday = true;
        } else {
          // Daily fallback probability: if weather API has no disaster, roll one locally.
          if (_random.nextDouble() < kDailyDisasterChance) {
            final rolled = [
              DisasterType.flood,
              DisasterType.storm,
              DisasterType.drought,
            ];
            final randomType = rolled[_random.nextInt(rolled.length)];
            triggerDisaster(randomType);
            disasterTriggeredToday = true;
          }
        }

        if (!disasterTriggeredToday) {
          clearDisaster();
        }

        // 2. BNPL Auto-payment / Penalty check
        for (final plan in bnplPlans) {
          if (plan.status == BnplStatus.active) {
            final result = await _cloud.calculateBnplPenalty(
              plan.id,
              currentDay,
            );
            // If a penalty was applied or defaulted, it modified the user wallet in Firestore
            if ((result['penalty'] != null && result['penalty'] > 0) ||
                (result['autoPaid'] == true) ||
                (result['paidInstallment'] == true)) {
              if (result['penalty'] != null && result['penalty'] > 0) {
                _addMonthlyExpense(
                  'interest',
                  (result['penalty'] as num).toDouble(),
                );
              }
              needsRefresh = true;
            }
          }
        }

        // If the server altered our wallet, fetch fresh state
        if (needsRefresh) {
          final updatedUser = await _firestore.getPlayer(
            player!.uid,
            forceRefresh: true,
          );
          if (updatedUser != null) {
            player = updatedUser;
            notifyListeners();
          }
        }

        // 3. Weekly Credit Score recalc
        if (currentDay % 7 == 0) {
          final creditResult = await _cloud.calculateCreditScore();
          if (creditResult['score'] != null) {
            player!.creditScore = creditResult['score'] as int;
            notifyListeners();
          }
        }
      }

      final monthChanged =
          (currentYear != previousYear) || (currentMonth != previousMonth);
      if (monthChanged) {
        _processLoanSharkRepaymentsOnMonthEnd();
        _pendingMonthlyReport = _buildMonthlyReport(
          reportYear: previousYear,
          reportMonth: previousMonth,
        );
      }

      return true;
    } finally {
      _isAdvancingDay = false;
    }
  }

  MonthlyPnLReport _buildMonthlyReport({
    required int reportYear,
    required int reportMonth,
  }) {
    final expenses = Map<String, double>.from(_monthlyExpenses);
    final totalExpense = expenses.values.fold(0.0, (sum, value) => sum + value);
    final netProfit = _monthlyIncome - totalExpense;

    String topCategory = 'none';
    double topValue = 0;
    expenses.forEach((category, value) {
      if (value > topValue) {
        topValue = value;
        topCategory = category;
      }
    });

    final report = MonthlyPnLReport(
      year: reportYear,
      month: reportMonth,
      income: _monthlyIncome,
      expenses: expenses,
      netProfit: netProfit,
      topExpenseCategory: topCategory,
    );

    for (final key in _monthlyExpenses.keys) {
      _monthlyExpenses[key] = 0;
    }
    _monthlyIncome = 0;

    return report;
  }

  Future<Map<String, dynamic>> repayBnplPlan(
    String planId,
    PaymentMethod method,
  ) async {
    if (player == null) {
      return {'paidInstallment': false, 'message': 'Player not loaded.'};
    }

    final result = await _cloud.repayBnplInstallment(
      planId,
      method.name,
      currentDay,
    );

    if (result['paidInstallment'] != true && player!.isAdmin == true) {
      final index = bnplPlans.indexWhere((plan) => plan.id == planId);
      if (index < 0) {
        return {
          'paidInstallment': false,
          'message': 'BNPL plan not found for admin fallback.',
        };
      }

      final plan = bnplPlans[index];
      if (plan.status != BnplStatus.active) {
        return {
          'paidInstallment': false,
          'message': 'Plan status is ${plan.status.name} and cannot be paid.',
        };
      }

      plan.paidInstallments = (plan.paidInstallments + 1).clamp(
        0,
        plan.installments,
      );
      plan.lateFees = 0;
      plan.nextDueDay = (plan.nextDueDay ?? currentDay) + kGameDaysPerMonth;
      plan.nextDueDate = DateTime.now().add(
        const Duration(days: kGameDaysPerMonth),
      );

      if (plan.paidInstallments >= plan.installments) {
        plan.status = BnplStatus.paid;
      }

      notifyListeners();
      return {
        'paidInstallment': true,
        'completed': plan.status == BnplStatus.paid,
        'adminBypass': true,
        'message': 'Admin test payment applied locally.',
      };
    }

    final updatedUser = await _firestore.getPlayer(
      player!.uid,
      forceRefresh: true,
    );
    if (updatedUser != null) {
      player = updatedUser;
    }

    final index = bnplPlans.indexWhere((plan) => plan.id == planId);
    if (index >= 0 && result['paidInstallment'] == true) {
      final plan = bnplPlans[index];
      plan.paidInstallments = (plan.paidInstallments + 1).clamp(
        0,
        plan.installments,
      );
      plan.lateFees = 0;
      plan.nextDueDay = (plan.nextDueDay ?? currentDay) + kGameDaysPerMonth;
      plan.nextDueDate = DateTime.now().add(
        const Duration(days: kGameDaysPerMonth),
      );
      if (result['completed'] == true ||
          plan.paidInstallments >= plan.installments) {
        plan.status = BnplStatus.paid;
      }
    }

    notifyListeners();
    return result;
  }

  /// Trigger a disaster event — destroy uninsured crops.
  int triggerDisaster(DisasterType type) {
    activeDisaster = type;
    var destroyed = 0;

    for (final row in grid) {
      for (final tile in row) {
        if (tile.hasCrop && !tile.insured) {
          tile.destroyCrop();
          destroyed++;
        }
      }
    }

    notifyListeners();
    _saveGridState(); // Persist disaster damage
    return destroyed;
  }

  /// Clear the active disaster.
  void clearDisaster() {
    activeDisaster = DisasterType.none;
    notifyListeners();
  }

  /// Pan camera by the given delta.
  void panCamera(Offset delta) {
    camera.pan(delta);
    notifyListeners();
  }

  /// Zoom camera by the given scale factor at the focal point.
  void zoomCamera(double scaleFactor, Offset focalPoint) {
    camera.zoom(camera.scale * scaleFactor, focalPoint);
    notifyListeners();
  }

  /// Center camera on the grid.
  void centerCamera(Size screenSize) {
    final bounds = engine.getGridBounds();
    camera.centerOn(bounds, screenSize);
    notifyListeners();
  }

  /// Convert grass tile to farmland (e.g., after buying land via loan).
  bool convertToFarmland(int col, int row) {
    if (!engine.isValidTile(col, row)) return false;
    final tile = grid[row][col];
    if (tile.type != TileType.grass) return false;
    tile.type = TileType.farmland;
    notifyListeners();
    return true;
  }

  /// Notify listeners that state has changed (called from UI after external mutation).
  void refresh() {
    notifyListeners();
  }

  @override
  void dispose() {
    _dayCycleTimer?.cancel();
    _loanSharkThreatTimer?.cancel();
    super.dispose();
  }
}

class MonthlyPnLReport {
  final int year;
  final int month;
  final double income;
  final Map<String, double> expenses;
  final double netProfit;
  final String topExpenseCategory;

  const MonthlyPnLReport({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
    required this.netProfit,
    required this.topExpenseCategory,
  });

  double get totalExpense =>
      expenses.values.fold(0.0, (sum, value) => sum + value);

  String get topExpenseLabel {
    switch (topExpenseCategory) {
      case 'seed':
        return 'Seeds';
      case 'interest':
        return 'Interest & Late Fees';
      case 'insurance':
        return 'Insurance';
      case 'equipment':
        return 'Equipment';
      case 'nextDayFee':
        return 'Next Day Fees';
      default:
        return 'N/A';
    }
  }
}
