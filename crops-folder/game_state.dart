import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/engine/camera.dart';
import 'package:farm_fintech/engine/isometric_engine.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';
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

  // ── Tiled Map Integration (for runtime crop growth stage display) ────
  RichiFarmGame? game; // Optional reference to update tile GIDs

  /// Crop GID mappings by stage.
  /// These values are calibrated to the three visible 4-frame rows in Basic_Plants.png.
  static const Map<CropType, List<int>> cropGidsByStage = {
    // Row 1: seed bag -> sprout -> tall stalk -> mature plant
    CropType.wheat: [258, 259, 260, 261], // stage 0..3 GIDs for wheat
    // Row 2: alternate crop row
    CropType.rice: [262, 263, 264, 265], // stage 0..3 GIDs for rice
    // Row 3: alternate crop row
    CropType.corn: [266, 267, 268, 269], // stage 0..3 GIDs for corn
  };

  // ── Player ──────────────────────────────────────────────────
  Player? player;

  // ── Grid ────────────────────────────────────────────────────
  late List<List<Tile>> grid;

  // ── Selection ───────────────────────────────────────────────
  (int, int)? selectedTile;

  void selectTile((int, int)? tile) {
    selectedTile = tile;
    notifyListeners();
  }

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

  GameState({this.game}) {
    _initGrid();
    _startDayCycleClock();
  }

  /// Mark farmable tiles based on a Tiled map's `FarmableArea` object layer.
  ///
  /// Expects an Object Layer named `FarmableArea` where each object
  /// represents a farmable tile (rectangle or point). Coordinates from
  /// Tiled are in pixels; we convert to grid col/row using `kTileWidth`.
  void markFarmableFromTiled(dynamic tiledMap) {
    try {
      if (tiledMap == null) return;

      final layers = tiledMap.layers;
      if (layers == null) return;

      for (final layer in layers) {
        final name = (layer.name as String?)?.trim();
        if (name == null) continue;
        final normalizedName = name.toLowerCase();
        if (normalizedName != 'farmablearea' &&
            normalizedName != 'tilled_dirt') {
          continue;
        }

        final layerProps = _extractTiledProperties(layer);

        // Support object layers
        final objects = layer.objects;
        if (objects != null) {
          for (final obj in objects) {
            final typeRaw = ((obj.type as String?) ?? '').toLowerCase();
            if (typeRaw.isNotEmpty && typeRaw != 'farmplot') {
              continue;
            }

            final mergedProps = <String, dynamic>{
              ...layerProps,
              ..._extractTiledProperties(obj),
            };

            // Tiled object coordinates are in pixels; map object rectangle
            // to tile range so one object can represent N x M plots.
            final dx = (obj.x as num?)?.toDouble() ?? 0.0;
            final dy = (obj.y as num?)?.toDouble() ?? 0.0;
            final w = (obj.width as num?)?.toDouble() ?? kTileWidth;
            final h = (obj.height as num?)?.toDouble() ?? kTileHeight;

            final startCol = (dx / kTileWidth).floor().clamp(0, kGridCols - 1);
            final startRow = (dy / kTileHeight).floor().clamp(0, kGridRows - 1);
            final endCol =
                ((dx + (w <= 0 ? kTileWidth : w) - 0.001) / kTileWidth)
                    .floor()
                    .clamp(0, kGridCols - 1);
            final endRow =
                ((dy + (h <= 0 ? kTileHeight : h) - 0.001) / kTileHeight)
                    .floor()
                    .clamp(0, kGridRows - 1);

            for (var row = startRow; row <= endRow; row++) {
              for (var col = startCol; col <= endCol; col++) {
                _applyFarmPlotFromTiledProperties(grid[row][col], mergedProps);
              }
            }
          }
        }

        // If it's a tile layer instead, mark non-zero GIDs as farmland
        try {
          final data = layer.data;
          if (data != null) {
            final mapWidth = tiledMap.width as int? ?? kGridCols;
            for (var idx = 0; idx < data.length; idx++) {
              final gid = data[idx] as int? ?? 0;
              if (gid != 0) {
                final r = (idx / mapWidth).floor();
                final c = idx % mapWidth;
                if (r >= 0 && r < grid.length && c >= 0 && c < grid[0].length) {
                  _applyFarmPlotFromTiledProperties(grid[r][c], layerProps);
                }
              }
            }
          }
        } catch (_) {
          // ignore — not a tile layer or unexpected format
        }
      }

      notifyListeners();
    } catch (e) {
      // ignore errors — best-effort marking
    }
  }

  Map<String, dynamic> _extractTiledProperties(dynamic node) {
    final out = <String, dynamic>{};
    try {
      final props = node.properties;
      if (props == null) return out;

      if (props is Map) {
        for (final entry in props.entries) {
          out['${entry.key}'.toLowerCase()] = entry.value;
        }
        return out;
      }

      if (props is List) {
        for (final p in props) {
          final key = (p.name as String?)?.toLowerCase();
          if (key == null || key.isEmpty) continue;
          out[key] = p.value;
        }
      }
    } catch (_) {}
    return out;
  }

  void _applyFarmPlotFromTiledProperties(
    Tile tile,
    Map<String, dynamic> props,
  ) {
    tile.type = TileType.farmland;

    final state = _parseFarmPlotState(props['farmstate'] ?? props['state']);
    final crop = _parseCropType(props['crop']);
    final growthStage = _parseInt(props['growthstage']);
    final plantedDay = _parseInt(props['plantedday']);
    final readyDay = _parseInt(props['readyday']);
    final witherAfterDays = _parseInt(props['witherafterdays']);
    final allowWither = _parseBool(props['allowwither']);

    if (state != null) {
      tile.setFarmStateFromTiled(
        state,
        cropType: crop,
        stage: growthStage,
        plantedDayValue: plantedDay,
        readyDayValue: readyDay,
        witherDays: witherAfterDays,
        witherEnabled: allowWither,
        currentDay: currentDay,
      );
      return;
    }

    if (witherAfterDays != null) {
      tile.witherAfterDays = witherAfterDays;
    }
    if (allowWither != null) {
      tile.allowWither = allowWither;
    }

    if (crop != null) {
      tile.crop = crop;
      tile.farmState = FarmPlotState.planted;
    }
    if (plantedDay != null) {
      tile.plantedDay = plantedDay;
    }
    if (growthStage != null) {
      tile.growthStage = growthStage.clamp(0, 3);
      if (tile.growthStage == 0) {
        tile.farmState = FarmPlotState.planted;
      } else if (tile.growthStage < 3) {
        tile.farmState = FarmPlotState.growing;
      } else {
        tile.farmState = FarmPlotState.ready;
        tile.readyDay ??= currentDay;
      }
    }
  }

  FarmPlotState? _parseFarmPlotState(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim().toLowerCase();
    switch (value) {
      case 'idle':
        return FarmPlotState.idle;
      case 'planted':
        return FarmPlotState.planted;
      case 'growing':
        return FarmPlotState.growing;
      case 'ready':
      case 'harvestable':
        return FarmPlotState.ready;
      case 'withered':
      case 'dead':
        return FarmPlotState.ready;
      default:
        return null;
    }
  }

  CropType? _parseCropType(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim().toLowerCase();
    for (final crop in CropType.values) {
      if (crop.name.toLowerCase() == value) {
        return crop;
      }
    }
    return null;
  }

  int? _parseInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString().trim());
  }

  bool? _parseBool(dynamic raw) {
    if (raw == null) return null;
    if (raw is bool) return raw;
    final value = raw.toString().trim().toLowerCase();
    if (value == 'true' || value == '1' || value == 'yes') return true;
    if (value == 'false' || value == '0' || value == 'no') return false;
    return null;
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

    // Always use fresh _initGrid() to ensure correct farmland layout
    // This overrides any old grid data saved in Firestore
    _initGrid();
    await _saveGridState(); // Save the fresh grid
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
        // Farmland regions (extracted from Tiled Tilled_Dirt layer)
        if (col >= 8 && col <= 10 && row >= 12 && row <= 14) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 16 && col <= 18 && row >= 12 && row <= 14) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 23 && col <= 25 && row >= 12 && row <= 26) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 27 && col <= 29 && row >= 12 && row <= 26) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 8 && col <= 10 && row >= 16 && row <= 18) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 16 && col <= 18 && row >= 16 && row <= 18) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 4 && col <= 6 && row >= 20 && row <= 22) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 8 && col <= 10 && row >= 20 && row <= 22) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 12 && col <= 14 && row >= 20 && row <= 22) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 16 && col <= 18 && row >= 20 && row <= 22) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 4 && col <= 6 && row >= 24 && row <= 26) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 8 && col <= 10 && row >= 24 && row <= 26) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 12 && col <= 14 && row >= 24 && row <= 26) {
          return Tile(col: col, row: row, type: TileType.farmland);
        }
        if (col >= 16 && col <= 18 && row >= 24 && row <= 26) {
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

    if (!tile.plant(cropType, currentDay: currentDay)) return false;

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
      syncCropGidsInTiledMap();
      notifyListeners();
      return true;
    } catch (_) {
      tile.crop = null;
      tile.growthStage = 0;
      tile.plantedAt = null;
      tile.plantedDay = null;
      tile.readyDay = null;
      tile.farmState = FarmPlotState.idle;
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
      syncCropGidsInTiledMap();
      notifyListeners();
      return harvested;
    } catch (_) {
      tile.crop = previousCrop;
      tile.growthStage = previousGrowthStage;
      tile.plantedAt = previousPlantedAt;
      tile.plantedDay = previousPlantedDay;
      tile.farmState = previousCrop == null
          ? FarmPlotState.idle
          : (previousGrowthStage >= 3
                ? FarmPlotState.ready
                : previousGrowthStage <= 0
                ? FarmPlotState.planted
                : FarmPlotState.growing);
      if (previousQuantity > 0) {
        player!.inventory[key] = previousQuantity;
      } else {
        player!.inventory.remove(key);
      }
      return null;
    }
  }

  /// Sync all crop tiles in the Tiled map with their current growth stages.
  ///
  /// This updates the GID (tile graphic ID) for each crop in the 'Crops' layer
  /// to reflect the current growthStage. Call this after advancing a day or
  /// when crop growth is updated.
  ///
  /// Requires: game reference set and cropGidsByStage configured with actual GIDs.
  void syncCropGidsInTiledMap() {
    if (game == null) {
      print(
        '[GameState] RichiFarmGame reference not set, skipping Tiled GID sync',
      );
      return;
    }

    // Try common layer names used in maps: prefer explicit 'Crops',
    // fall back to 'Tilled_Dirt' if present.
    final candidateNames = ['Crops', 'Tilled_Dirt'];
    String? foundLayerName;
    for (final candidate in candidateNames) {
      try {
        if (game!.hasLayer(candidate)) {
          foundLayerName = candidate;
          break;
        }
      } catch (_) {}
    }
    if (foundLayerName == null) {
      print('[GameState] No suitable tile layer found (tried ${candidateNames.join(', ')}), skipping sync');
      return;
    }
    final layerName = foundLayerName;
    int syncedCount = 0;

    for (int row = 0; row < grid.length; row++) {
      for (int col = 0; col < grid[row].length; col++) {
        final tile = grid[row][col];

        final crop = tile.crop;
        if (crop != null) {
          final gids = cropGidsByStage[crop];
          if (gids != null && gids.isNotEmpty) {
            final stageIdx = tile.growthStage.clamp(0, gids.length - 1);
            final newGid = gids[stageIdx];

            game!.setTileGidAt(layerName, col, row, newGid);
            syncedCount++;
          }
        }
      }
    }

    if (syncedCount > 0) {
      print('[GameState] Synced $syncedCount crop tiles in Tiled map');
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
        if (!tile.hasCrop || tile.growthStage >= 3) {
          continue;
        }
        previousGrowthStages[tile] = tile.growthStage;
        tile.growthStage = (tile.growthStage + 1).clamp(0, 3);
        if (tile.growthStage >= 3) {
          tile.farmState = FarmPlotState.ready;
          tile.readyDay ??= currentDay;
        } else if (tile.growthStage >= 1) {
          tile.farmState = FarmPlotState.growing;
        } else {
          tile.farmState = FarmPlotState.planted;
        }
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

      // Grow crops based on in-game days using FarmPlot state machine
      for (final row in grid) {
        for (final tile in row) {
          if (tile.hasCrop && tile.growthStage < 3) {
            final config = kCropConfig[tile.crop!]!;
            final growthDays = config['growthDays'] as int;
            tile.advanceLifecycle(
              currentDay: currentDay,
              growthDays: growthDays,
            );
          } else if (tile.hasCrop && tile.growthStage >= 3) {
            final config = kCropConfig[tile.crop!]!;
            final growthDays = config['growthDays'] as int;
            tile.advanceLifecycle(
              currentDay: currentDay,
              growthDays: growthDays,
            );
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

      // Sync crop growth stages to Tiled map
      syncCropGidsInTiledMap();

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
