import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';
import 'package:farm_fintech/models/player.dart';
import 'package:farm_fintech/models/tile.dart';
import 'package:farm_fintech/models/quest.dart';
import 'package:farm_fintech/models/financial/transaction.dart';
import 'package:farm_fintech/models/financial/loan.dart';
import 'package:farm_fintech/models/financial/insurance.dart';
import 'package:farm_fintech/models/financial/bnpl_plan.dart';
import 'package:farm_fintech/models/financial/fixed_deposit.dart';
import 'package:farm_fintech/models/weather_event.dart';
import 'package:farm_fintech/services/cloud_functions_service.dart';
import 'package:farm_fintech/services/firestore_service.dart';
import 'package:farm_fintech/services/weather_service.dart';
import 'package:farm_fintech/engine/components/interactive_building_component.dart';
import 'package:farm_fintech/engine/components/shady_lender_component.dart';
import 'package:farm_fintech/services/gemini_service.dart';

enum InteractionMenuState { main, plant, harvest, confirmRemove, lyra }

/// Central game state managed via [ChangeNotifier].
class GameState extends ChangeNotifier {
  final CloudFunctionsService _cloud = CloudFunctionsService();
  final WeatherService _weather = WeatherService();
  final FirestoreService _firestore = FirestoreService();
  final Random _random = Random();

  // ── Flame game reference (for crop sprite sync) ─────────────
  RichiFarmGame? game;

  // ── Loading State ───────────────────────────────────────────
  bool isLoading = true;

  // ── Player ──────────────────────────────────────────────────
  Player? player;

  // ── Grid ────────────────────────────────────────────────────
  late List<List<Tile>> grid;

  // ── Selection ───────────────────────────────────────────────
  (int, int)? selectedTile;

  /// Select a tile by grid coordinates (called from RichiFarmGame tap handler).
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
  bool isFlooded = false;
  int _remainingCycleSeconds = kGameDayDurationMinutes * 60;
  int _manualNextDayUsedToday = 0;
  DateTime _manualNextDayUsageDate = DateTime.now();
  Timer? _dayCycleTimer;
  Timer? _loanSharkThreatTimer;
  bool _isAdvancingDay = false;
  int _timeSaveCountdown = 0; // Counts down; save when reaching 0
  AppLifecycleListener? _lifecycleListener;
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

  // ── Interaction ───────────────────────────────────────────────
  (int, int)? interactableTile;
  InteractiveBuildingComponent? interactableBuilding;
  ShadyLenderComponent? interactableShadyLender;
  bool showShadyDialogue = false;
  bool isNearLyra = false;
  InteractionMenuState interactionMenuState = InteractionMenuState.main;
  List<Map<String, String>> chatHistory = [];
  
  // ── Notifications ───────────────────────────────────────────
  final List<NotificationItem> notifications = [];
  void addNotification(String message, {IconData icon = Icons.info_outline, Color color = const Color(0xFF5D4037)}) {
    final item = NotificationItem(message: message, icon: icon, color: color);
    notifications.add(item);
    notifyListeners();
    Future.delayed(const Duration(seconds: 4), () {
      notifications.remove(item);
      notifyListeners();
    });
  }

  Quest? activeQuest;

  void updateInteractableTile((int, int)? tile) {
    if (interactableTile?.$1 == tile?.$1 && interactableTile?.$2 == tile?.$2) return;
    interactableTile = tile;
    interactionMenuState = InteractionMenuState.main; // Reset menu on tile change
    notifyListeners();
  }

  void updateInteractableBuilding(InteractiveBuildingComponent? building) {
    if (interactableBuilding == building) return;
    interactableBuilding = building;
    interactionMenuState = InteractionMenuState.main;
    notifyListeners();
  }

  void updateInteractableShadyLender(ShadyLenderComponent? lender) {
    if (interactableShadyLender == lender) return;
    interactableShadyLender = lender;
    notifyListeners();
  }

  void updateNearLyra(bool near) {
    if (isNearLyra == near) return;
    isNearLyra = near;
    if (!near) interactionMenuState = InteractionMenuState.main;
    notifyListeners();
  }

  void addChatMessage(String role, String content) {
    chatHistory.add({'role': role, 'content': content});
    notifyListeners();
  }

  void setInteractionMenuState(InteractionMenuState state) {
    if (interactionMenuState == state) return;
    interactionMenuState = state;
    notifyListeners();
  }

  Future<bool> removeCrop() async {
    if (interactableTile == null || player == null) return false;
    final (col, row) = interactableTile!;
    final tile = grid[row][col];

    if (!tile.hasCrop) return false;

    tile.destroyCrop();

    try {
      await _saveGridState();
      game?.removeCropComponent(col, row);
      interactionMenuState = InteractionMenuState.main;
      notifyListeners();
      return true;
    } catch (_) {
      // Revert is complex, but in a simple implementation, we can assume success
      return false;
    }
  }

  void handleInteractionKey(int key) {
    if (interactableBuilding != null) {
      if (key == 1 && interactionMenuState == InteractionMenuState.main) {
        // Trigger the building overlay
        game?.onBuildingTapped?.call(interactableBuilding!.type);
      }
      return;
    }

    if (isNearLyra) {
      if (interactionMenuState == InteractionMenuState.main) {
        if (key == 1) { // 'F' key mapping
          setInteractionMenuState(InteractionMenuState.lyra);
        }
      } else if (interactionMenuState == InteractionMenuState.lyra) {
        if (key == 1) {
          game?.onLyraTapped?.call();
          setInteractionMenuState(InteractionMenuState.main);
        } else if (key == 2) {
          game?.onLyraQuestTapped?.call();
          setInteractionMenuState(InteractionMenuState.main);
        }
      }
      return;
    }

    if (interactableTile == null) return;
    final (col, row) = interactableTile!;
    final tile = grid[row][col];

    if (interactionMenuState == InteractionMenuState.main) {
      if (!tile.hasCrop) {
        // Empty tile: 1. Plant
        if (key == 1) setInteractionMenuState(InteractionMenuState.plant);
      } else if (tile.isHarvestable) {
        // Ready tile: 1. Harvest, 2. Remove
        if (key == 1) {
          harvestCropInteraction();
        } else if (key == 2) {
          setInteractionMenuState(InteractionMenuState.confirmRemove);
        }
      } else if (tile.hasCrop) {
        // Growing tile: 1. Remove
        if (key == 1) {
          setInteractionMenuState(InteractionMenuState.confirmRemove);
        }
      }
    } else if (interactionMenuState == InteractionMenuState.plant) {
      if (key == 1) {
        plantCropInteraction(CropType.wheat);
      } else if (key == 2) plantCropInteraction(CropType.rice);
      else if (key == 3) plantCropInteraction(CropType.corn);
    } else if (interactionMenuState == InteractionMenuState.confirmRemove) {
      if (key == 1) {
        removeCrop();
      } else if (key == 2) setInteractionMenuState(InteractionMenuState.main);
    }
  }

  void handleInteractionAction(String action) {
    // Selection navigation logic can be added here if needed
  }

  Future<void> plantCropInteraction(CropType type) async {
    // Temporary override selectedTile for plantCrop to work
    final oldSelected = selectedTile;
    selectedTile = interactableTile;
    await plantCrop(type);
    selectedTile = oldSelected;
    setInteractionMenuState(InteractionMenuState.main);
  }

  Future<void> harvestCropInteraction() async {
    final oldSelected = selectedTile;
    selectedTile = interactableTile;
    await harvestCrop();
    selectedTile = oldSelected;
    setInteractionMenuState(InteractionMenuState.main);
  }

  GameState() {
    _initGrid();
    // Do NOT start the clock here. It must wait until setPlayer finishes
    // loading the currentDay from Firestore to avoid race conditions.
  }

  /// Fully resets all in-memory game state for a clean logout.
  ///
  /// Must be called BEFORE navigating to the login screen so the
  /// next user doesn't inherit a stale UID, timers, or subscriptions.
  void resetForLogout() {
    // Stop all timers
    _dayCycleTimer?.cancel();
    _dayCycleTimer = null;
    _loanSharkThreatTimer?.cancel();
    _loanSharkThreatTimer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;

    // Cancel Firestore subscriptions
    _bnplPlansSub?.cancel();
    _bnplPlansSub = null;
    _txSub?.cancel();
    _txSub = null;

    // Clear player and game reference
    player = null;
    game = null;

    // Clear the Firestore service cache to prevent stale UID data
    _firestore.clearCache();

    // Reset grid to default empty state
    _initGrid();

    // Reset all session variables
    currentDay = 1;
    _remainingCycleSeconds = kGameDayDurationMinutes * 60;
    _manualNextDayUsedToday = 0;
    _manualNextDayUsageDate = DateTime.now();
    _isAdvancingDay = false;
    _timeSaveCountdown = 0;
    _loanSharkThreatSecondsRemaining = 0;
    selectedTile = null;
    interactableTile = null;
    interactableBuilding = null;
    interactableShadyLender = null;
    interactionMenuState = InteractionMenuState.main;
    selectedCropToPlant = null;
    activeDisaster = DisasterType.none;
    bnplPlans = [];
    loans = [];
    insurances = [];
    _monthlyIncome = 0;
    _pendingMonthlyReport = null;
    _monthlyExpenses.updateAll((key, value) => 0);
    isLoading = true;

    notifyListeners();
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

  bool _isCameraFollow = true;
  bool get isCameraFollow => _isCameraFollow;

  final Set<String> visitedLocations = {};

  void visitLocation(String locationId) {
    visitedLocations.add(locationId);
    updateQuestProgress(QuestType.location, 1.0, location: locationId);
  }

  void updateQuestProgress(QuestType type, double amount, {CropType? crop, String? location}) {
    if (activeQuest == null || activeQuest!.status != QuestStatus.active) return;

    if (type == QuestType.location) {
      if (activeQuest!.type != QuestType.location) return;
      if (activeQuest!.targetLocation != location) return;
      activeQuest!.currentProgress = activeQuest!.goalAmount;
      notifyListeners();
      return;
    }

    // delivery and urgent quests count harvest actions as progress
    final activeType = activeQuest!.type;
    final isHarvestLike = activeType == QuestType.delivery || activeType == QuestType.urgent;
    if (activeType != type && !(type == QuestType.harvest && isHarvestLike)) return;
    if ((type == QuestType.harvest || isHarvestLike) && activeQuest!.targetCrop != crop) return;

    activeQuest!.currentProgress += amount;
    if (activeQuest!.currentProgress >= activeQuest!.goalAmount) {
      // Completed! We don't auto-complete here, maybe wait for Lyra visit or just auto-reward
    }
    notifyListeners();
    _savePlayerState();
  }

  Future<bool> acceptQuest(Quest quest) async {
    if (player == null || activeQuest != null) return false;
    if (player!.cashBalance < quest.cost) return false;

    player!.cashBalance -= quest.cost;
    activeQuest = quest;
    notifyListeners();
    await _savePlayerState();
    return true;
  }

  Future<void> checkQuestStatus() async {
    if (activeQuest == null || activeQuest!.status != QuestStatus.active) return;

    if (activeQuest!.currentProgress >= activeQuest!.goalAmount) {
      activeQuest!.status = QuestStatus.completed;
      player!.cashBalance += activeQuest!.reward;
      // Log transaction
      await FirestoreService().addTransaction(player!.uid, Transaction(
        id: '',
        paymentType: TransactionType.cash,
        amount: activeQuest!.reward,
        category: TransactionCategory.other,
        timestamp: DateTime.now(),
        description: 'Quest Reward: ${activeQuest!.title}',
      ));
    } else if (currentDay > activeQuest!.endDay) {
      activeQuest!.status = QuestStatus.failed;
    }
    
    if (activeQuest!.status != QuestStatus.active) {
      // Keep it for a bit to show user? Or just clear?
      // Let's clear it when they talk to Lyra next or after some time.
    }
    notifyListeners();
    await _savePlayerState();
  }
  void toggleCameraFollow() {
    _isCameraFollow = !_isCameraFollow;
    notifyListeners();
  }

  int get freeNextDayRemaining {
    _resetManualNextDayIfNewDate();
    return (kFreeManualNextDayPerRealDay - _manualNextDayUsedToday).clamp(
      0,
      kFreeManualNextDayPerRealDay,
    );
  }

  void _startDayCycleClock({int? initialSeconds}) {
    _dayCycleTimer?.cancel();
    if (initialSeconds != null) {
      _remainingCycleSeconds = initialSeconds;
    }
    _timeSaveCountdown = 15; // First save after 15 seconds
    _dayCycleTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_isAdvancingDay) return;
      _remainingCycleSeconds--;
      if (_remainingCycleSeconds <= 0) {
        await _advanceDayCore(isManual: false);
        _remainingCycleSeconds = kGameDayDurationMinutes * 60;
        _timeSaveCountdown = 15; // Reset after day advance (which already saves)
      } else {
        // Throttled time persistence: save every 15 seconds
        _timeSaveCountdown--;
        if (_timeSaveCountdown <= 0) {
          _timeSaveCountdown = 15;
          _savePlayerState(); // Fire-and-forget; no need to await
        }
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

  @override
  void dispose() {
    // Persist time progress one last time before shutdown
    _savePlayerState();
    _dayCycleTimer?.cancel();
    _loanSharkThreatTimer?.cancel();
    _bnplPlansSub?.cancel();
    _txSub?.cancel();
    _lifecycleListener?.dispose();
    super.dispose();
  }

  // ── Tiled map integration ───────────────────────────────────

  /// Mark farmable tiles based on a Tiled map's tile/object layers.
  ///
  /// Reads layers named 'FarmableArea' or 'Tilled_Dirt' from the TMX.
  /// For tile layers, any non-zero GID marks the tile as farmland.
  /// For object layers, rectangle objects mark farmland regions.
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

        // If it's a tile layer, mark non-zero GIDs as farmland
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
                  grid[r][c].type = TileType.farmland;
                  grid[r][c].farmState = FarmPlotState.idle;
                }
              }
            }
          }
        } catch (_) {
          // ignore — not a tile layer or unexpected format
        }

        // Support object layers
        try {
          final objects = layer.objects;
          if (objects != null) {
            for (final obj in objects) {
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
                  grid[row][col].type = TileType.farmland;
                  grid[row][col].farmState = FarmPlotState.idle;
                }
              }
            }
          }
        } catch (_) {
          // ignore — not an object layer
        }
      }

      notifyListeners();
    } catch (_) {
      // ignore errors — best-effort marking
    }
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

  /// Total outstanding debt across all active shark loans.
  double get sharkDebt {
    double total = 0;
    for (final loan in loans) {
      if (loan.id.startsWith('shark-') && loan.status == LoanStatus.active) {
        total += loan.remainingBalance;
      }
    }
    return total;
  }

  /// Repay shark loans by a given amount. Returns the actual amount repaid.
  Future<double> repaySharkLoan(double amount) async {
    final p = player;
    if (p == null || amount <= 0) return 0;

    // Cap to what they can afford (prefer cash, then bank)
    final affordable = p.cashBalance + p.bankBalance;
    final toRepay = amount.clamp(0.0, affordable).clamp(0.0, sharkDebt);
    if (toRepay <= 0) return 0;

    double remaining = toRepay;

    // Deduct from cash first, then bank
    if (p.cashBalance >= remaining) {
      p.pay(remaining, method: PaymentMethod.cash);
    } else {
      final fromCash = p.cashBalance;
      if (fromCash > 0) p.pay(fromCash, method: PaymentMethod.cash);
      final fromBank = remaining - fromCash;
      if (fromBank > 0) p.pay(fromBank, method: PaymentMethod.bank);
    }

    // Apply repayment across active shark loans
    for (final loan in loans) {
      if (remaining <= 0) break;
      if (!loan.id.startsWith('shark-') || loan.status != LoanStatus.active) continue;

      final applied = remaining.clamp(0.0, loan.remainingBalance);
      loan.remainingBalance -= applied;
      remaining -= applied;

      if (loan.remainingBalance <= 0.01) {
        loan.remainingBalance = 0;
        loan.status = LoanStatus.paid;
      }
    }

    _addMonthlyExpense('interest', toRepay);

    try {
      await _savePlayerState();
      await _saveGridState();
    } catch (_) {
      // Best-effort save
    }

    notifyListeners();
    return toRepay;
  }

  /// Set player and load their specific grid if it exists
  Future<void> setPlayer(Player newPlayer) async {
    isLoading = true;
    player = newPlayer;
    // Sync state variables from persisted player object
    currentDay = newPlayer.currentDay;
    _remainingCycleSeconds = newPlayer.remainingCycleSeconds;
    _manualNextDayUsedToday = newPlayer.manualNextDayUsedToday;
    _manualNextDayUsageDate = newPlayer.manualNextDayUsageDate;
    isFlooded = newPlayer.isFlooded;

    // Do not notifyListeners early if we are showing a loading screen.
    // Wait for grid to be fully fetched.

    final savedGrid = await _firestore.getGrid(newPlayer.uid);
    if (savedGrid != null) {
      grid = savedGrid;
      // Re-apply farmland tiles if the Tiled map is already loaded.
      // Resolves race condition where markFarmableFromTiled is overwritten.
      if (game?.isLoaded ?? false) {
        try {
          final mapComp = game?.mapComponent;
          if (mapComp != null) {
            markFarmableFromTiled(mapComp.tileMap.map);
          }
        } catch (_) {}
      }
      game?.syncCropsFromGameState();
    } else {
      _initGrid(); // Fallback to default
      if (game?.isLoaded ?? false) {
        try {
          final mapComp = game?.mapComponent;
          if (mapComp != null) {
            markFarmableFromTiled(mapComp.tileMap.map);
          }
        } catch (_) {}
      }
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

    // Start the day cycle clock from the restored time position
    _startDayCycleClock(initialSeconds: _remainingCycleSeconds);

    // Listen for app lifecycle changes (browser tab close, mobile background)
    // to persist time progress immediately.
    _lifecycleListener?.dispose();
    _lifecycleListener = AppLifecycleListener(
      onInactive: () => _savePlayerState(),
      onPause: () => _savePlayerState(),
      onDetach: () => _savePlayerState(),
      onHide: () => _savePlayerState(),
    );

    // Save immediately to lock in the restored time (important for web refresh)
    await _savePlayerState();

    isLoading = false;
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

  /// Initialize grid with all grass tiles.
  /// Farmland positions come from the TMX Tilled_Dirt layer via [markFarmableFromTiled].
  void _initGrid() {
    grid = List.generate(
      kGridRows,
      (row) => List.generate(
        kGridCols,
        (col) => Tile(col: col, row: row, type: TileType.grass),
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────

  Future<void> _savePlayerState() async {
    if (player == null) return;
    // Sync the current intra-day time back to the player model before saving
    player!.remainingCycleSeconds = _remainingCycleSeconds;
    player!.currentDay = currentDay;
    player!.isFlooded = isFlooded;
    await _firestore.savePlayer(player!);
  }

  // handleTap is now in RichiFarmGame.handleTap() — it calls selectTile().

  /// Buy seeds from merchant
  Future<bool> buySeeds(CropType type, int quantity, {bool free = false}) async {
    if (player == null) return false;
    final config = kCropConfig[type]!;
    final cost = (config['seedCost'] as double) * quantity;

    if (!free) {
      if (player!.cashBalance + player!.bankBalance < cost) return false;

      if (player!.cashBalance >= cost) {
        player!.pay(cost, method: PaymentMethod.cash);
      } else {
        player!.pay(cost, method: PaymentMethod.bank);
      }
      _addMonthlyExpense('seed', cost);
    }

    final seedKey = '${type.name}_seed';
    final current = player!.inventory[seedKey] ?? 0;
    player!.inventory[seedKey] = current + quantity;

    try {
      await _savePlayerState();
      notifyListeners();
      addNotification('Bought $quantity x ${config['name']} Seeds${free ? ' (BNPL)' : ''}', icon: Icons.shopping_bag, color: Colors.green.shade700);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Developer Option: Add Money
  Future<void> devAddMoney(double amount) async {
    if (player == null) return;
    player!.cashBalance += amount;
    await _savePlayerState();
    notifyListeners();
  }

  /// Developer Option: Set Credit Score to Max
  Future<void> devSetMaxCredit() async {
    if (player == null) return;
    player!.creditScore = kMaxCreditScore;
    await _savePlayerState();
    notifyListeners();
  }

  /// Developer Option: Remove All Plants
  Future<void> devRemoveAllPlants() async {
    for (final row in grid) {
      for (final tile in row) {
        tile.crop = null;
        tile.farmState = FarmPlotState.idle;
        tile.growthStage = 0;
      }
    }
    await _saveGridState();
    game?.syncCropsFromGameState();
    notifyListeners();
  }

  /// Developer Option: Remove Money
  Future<void> devRemoveMoney(double amount) async {
    if (player == null) return;
    player!.cashBalance = (player!.cashBalance - amount).clamp(0, double.infinity);
    await _savePlayerState();
    notifyListeners();
  }

  /// Developer Option: Grow All Crops Instantly
  Future<void> devGrowAllCrops() async {
    for (final row in grid) {
      for (final tile in row) {
        if (tile.hasCrop) {
          tile.growthStage = 3;
          tile.farmState = FarmPlotState.ready;
          tile.readyDay ??= currentDay;
        }
      }
    }
    await _saveGridState();
    game?.syncCropsFromGameState();
    notifyListeners();
  }

  /// Developer Option: Randomly plant many seeds on farmland
  Future<void> devRandomlyPlant() async {
    final crops = CropType.values;
    for (final row in grid) {
      for (final tile in row) {
        if (tile.isFarmland && !tile.hasCrop) {
          // 20% chance to plant on each farmland tile
          if (_random.nextDouble() < 0.2) {
            final randomCrop = crops[_random.nextInt(crops.length)];
            tile.plant(randomCrop, currentDay: currentDay);
            // Randomly set growth stage (0-3)
            tile.growthStage = _random.nextInt(4);
            if (tile.growthStage >= 3) {
              tile.farmState = FarmPlotState.ready;
              tile.readyDay = currentDay;
            } else if (tile.growthStage >= 1) {
              tile.farmState = FarmPlotState.growing;
            }
          }
        }
      }
    }
    await _saveGridState();
    game?.syncCropsFromGameState();
    notifyListeners();
  }

  /// Developer Option: Reset Game
  Future<void> devResetGame() async {
    if (player == null) return;
    final uid = player!.uid;
    
    // 1. Reset Player Stats
    player = Player(
      uid: uid,
      displayName: player!.displayName,
      country: player!.country,
      currency: player!.currency,
      cashBalance: kStartingCash,
      bankBalance: 0,
      creditScore: kStartingCreditScore,
      currentDay: 1,
    );
    currentDay = 1;
    
    // 2. Clear Inventory
    player!.inventory.clear();
    player!.tractorOwned = false;
    player!.autoHarvestEnabled = false;
    player!.fertilizerPackCount = 0;
    
    // 3. Clear Financial Items (Cloud subcollections should be cleared if possible, but locally we wipe)
    await _firestore.clearBnplPlans(uid);
    await _firestore.clearInsurancePolicies(uid);
    await _firestore.clearBankAccounts(uid);
    
    // 4. Clear Grid
    for (final row in grid) {
      for (final tile in row) {
        tile.crop = null;
        tile.farmState = FarmPlotState.idle;
        tile.growthStage = 0;
      }
    }
    
    await _savePlayerState();
    await _saveGridState();
    game?.syncCropsFromGameState();
    
    // 5. Reset UI lists
    bnplPlans = [];
    insurances = [];
    
    notifyListeners();
  }

  /// Developer Option: Skip Multiple Days (High Efficiency)
  Future<void> devSkipDays(int days) async {
    if (days <= 0 || player == null) return;
    
    // 1. Advance Game Time
    currentDay += days;
    player!.currentDay = currentDay;
    
    // 2. Bulk Grow All Crops
    for (final row in grid) {
      for (final tile in row) {
        if (tile.hasCrop) {
          // In a 30-day skip, all current crops will definitely reach maturity
          tile.growthStage = 3;
          tile.farmState = FarmPlotState.ready;
          tile.readyDay ??= currentDay;
        }
      }
    }
    
    // 3. Bulk Financial Calculations (Late Fees)
    for (final plan in bnplPlans) {
      if (plan.status == BnplStatus.active && plan.nextDueDay != null) {
        if (currentDay > plan.nextDueDay!) {
          final daysPast = currentDay - plan.nextDueDay!;
          final monthsMissed = (daysPast / kGameDaysPerMonth).floor() + 1;
          plan.lateFees += (plan.monthlyAmount * kBnplLateFeePercent) * monthsMissed;
        }
      }
    }

    // 4. Bulk Insurance Expiration
    insurances.removeWhere((ins) => ins.isExpired(currentDay));
    player!.insurances.removeWhere((ins) => ins.isExpired(currentDay));

    // 5. Persistence (Single Pass)
    await _savePlayerState();
    await _saveGridState();
    game?.syncCropsFromGameState();
    
    addNotification('Instantly skipped $days days!', icon: Icons.bolt, color: Colors.amber.shade900);
    notifyListeners();
  }

  /// Plant a crop on the selected tile.
  Future<bool> plantCrop(CropType cropType) async {
    if (selectedTile == null || player == null) return false;
    if (isFlooded) {
      addNotification('Cannot plant while flooded!', icon: Icons.warning, color: Colors.red);
      return false;
    }

    final (col, row) = selectedTile!;
    final tile = grid[row][col];
    final config = kCropConfig[cropType]!;
    final seedKey = '${cropType.name}_seed';
    
    // Check inventory for seeds
    final seedCount = player!.inventory[seedKey] ?? 0;
    if (seedCount <= 0) {
      return false;
    }

    if (!tile.plant(cropType, currentDay: currentDay)) return false;

    // Consume 1 seed
    player!.inventory[seedKey] = seedCount - 1;

    // Removed direct deduction and monthly expense for seed since it's now bought from merchant

    try {
      await _savePlayerState();
      await _saveGridState();
      // Add crop sprite on the map
      game?.addCropComponent(col, row, cropType, 0);
      notifyListeners();
      return true;
    } catch (_) {
      tile.crop = null;
      tile.growthStage = 0;
      tile.plantedAt = null;
      tile.plantedDay = null;
      tile.readyDay = null;
      tile.farmState = FarmPlotState.idle;
      player!.inventory[seedKey] = seedCount; // Restore seed
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
    final previousFarmState = tile.farmState;
    final harvested = tile.harvest();

    if (harvested == null) return null;

    final key = harvested.name;
    final previousQuantity = player!.inventory[key] ?? 0;
    player!.inventory[key] = previousQuantity + 1;

    try {
      await _savePlayerState();
      await _saveGridState();
      // Remove crop sprite from the map
      game?.removeCropComponent(col, row);
      updateQuestProgress(QuestType.harvest, 1.0, crop: harvested);
      notifyListeners();
      return harvested;
    } catch (_) {
      tile.crop = previousCrop;
      tile.growthStage = previousGrowthStage;
      tile.plantedAt = previousPlantedAt;
      tile.plantedDay = previousPlantedDay;
      tile.farmState = previousFarmState;
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
      updateQuestProgress(QuestType.cash, revenue);
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
      addNotification('Successfully purchased equipment!', icon: Icons.shopping_cart, color: Colors.blue.shade700);
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

  /// Purchase an item using BNPL (Buy Now, Pay Later).
  ///
  /// Creates a BNPL plan with the given number of installments and
  /// immediately unlocks the equipment but requires the first installment upfront.
  Future<bool> purchaseWithBnpl(
    String itemName,
    double baseAmount,
    int installments,
  ) async {
    if (player == null) return false;

    // Apply 5% processing fee for 6-month plans
    final totalAmount = installments == 6 ? baseAmount * 1.05 : baseAmount;
    final monthlyAmount = totalAmount / installments;

    // Require first installment upfront
    if (player!.cashBalance < monthlyAmount) {
      addNotification('Insufficient cash for 1st installment.', icon: Icons.warning, color: Colors.red);
      return false;
    }

    // Deduct 1st installment
    player!.cashBalance -= monthlyAmount;

    // Calculate next due day: 1st day of the month after next
    // e.g., buy in month 1 → due on month 3 day 1
    final currentMonth = ((currentDay - 1) ~/ kGameDaysPerMonth);
    final nextDueDayValue = (currentMonth + 2) * kGameDaysPerMonth + 1;

    final plan = BnplPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      itemName: itemName,
      totalAmount: totalAmount,
      installments: installments,
      monthlyAmount: monthlyAmount,
      nextDueDate: DateTime.now().add(const Duration(days: 2 * kGameDaysPerMonth)),
      nextDueDay: nextDueDayValue,
    );
    
    // First payment is made upfront
    plan.paidInstallments = 1;

    try {
      await _savePlayerState();
      
      // Write the BNPL plan to Firestore.
      await _firestore.createBnplPlan(player!.uid, plan);

      // Unlock the equipment immediately (the player pays over time).
      await unlockEquipment(itemName);

      _addMonthlyExpense('equipment', monthlyAmount);

      // Log a transaction for credit score tracking
      await _firestore.logTransaction(
        player!.uid,
        amount: totalAmount,
        paymentType: 'bnpl',
        category: 'bnplPurchase',
      );

      notifyListeners();
      addNotification('BNPL Purchase Successful!', icon: Icons.credit_card, color: Colors.orange.shade700);
      return true;
    } catch (e) {
      debugPrint('purchaseWithBnpl error: $e');
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
        tile.growthStage = 3; // Boost to maximum stage immediately
        tile.farmState = FarmPlotState.ready;
        tile.readyDay ??= currentDay;
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
      await _saveGridState();
      game?.syncCropsFromGameState();
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

    int harvestedCount = 0;
    if (enabled) {
      harvestedCount = _applyAutoHarvest();
    }

    try {
      await _savePlayerState();
      await _saveGridState();
      game?.syncCropsFromGameState();
      
      if (harvestedCount > 0) {
        addNotification('Tractor harvested $harvestedCount crops!', icon: Icons.agriculture, color: Colors.green.shade900);
      }
      
      notifyListeners();
      return true;
    } catch (_) {
      player!.autoHarvestEnabled = previous;
      return false;
    }
  }

  Future<bool> updateDisplayName(String newName) async {
    if (player == null || newName.trim().isEmpty) return false;

    final previous = player!.displayName;
    player!.displayName = newName.trim();

    try {
      await _savePlayerState();
      notifyListeners();
      return true;
    } catch (_) {
      player!.displayName = previous;
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

    await _advanceDayCore(isManual: true);
    await checkQuestStatus();
    return true;
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

      // Grow crops using lifecycle state machine
      for (final row in grid) {
        for (final tile in row) {
          if (tile.hasCrop) {
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

      // Reset daily disaster states
      isFlooded = false;

      // Expire insurances
      if (player != null) {
        player!.insurances.removeWhere((i) => i.isExpired(currentDay));
      }

      // Sync crop sprites with updated growth stages
      game?.syncCropsFromGameState();

      // 4. Bank Logic: Interest and Maturity
      _processInterestsAndMaturity();

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

    if (result['paidInstallment'] != true) {
      // Cloud function failed — use local fallback
      final index = bnplPlans.indexWhere((plan) => plan.id == planId);
      if (index < 0) {
        return {
          'paidInstallment': false,
          'message': 'BNPL plan not found for fallback.',
        };
      }

      final plan = bnplPlans[index];
      if (plan.status != BnplStatus.active) {
        return {
          'paidInstallment': false,
          'message': 'Plan status is ${plan.status.name} and cannot be paid.',
        };
      }

      final amountDue = plan.monthlyAmount + plan.lateFees;

      // Deduct cash locally
      if (method == PaymentMethod.cash) {
        if (player!.cashBalance < amountDue) {
          return {
            'paidInstallment': false,
            'message': 'Insufficient cash.',
          };
        }
        player!.cashBalance -= amountDue;
      }

      // Update the plan object for Firestore write
      plan.paidInstallments = (plan.paidInstallments + 1).clamp(0, plan.installments);
      plan.lateFees = 0;
      plan.nextDueDay = (plan.nextDueDay ?? currentDay) + kGameDaysPerMonth;
      plan.nextDueDate = DateTime.now().add(const Duration(days: kGameDaysPerMonth));

      final isFullyPaid = plan.paidInstallments >= plan.installments;

      if (isFullyPaid) {
        // Delete from Firestore — stream will auto-remove from local list
        await _firestore.getDb()
          .collection('users')
          .doc(player!.uid)
          .collection('bnplPlans')
          .doc(plan.id)
          .delete();
      } else {
        // Update the plan in Firestore — stream will auto-update local list
        await _firestore.createBnplPlan(player!.uid, plan);
      }

      await _firestore.savePlayer(player!);
      notifyListeners();
      return {
        'paidInstallment': true,
        'completed': isFullyPaid,
        'fallback': true,
        'message': 'Payment applied locally.',
      };
    }

    // Cloud function succeeded — refresh player balance from Firestore
    final updatedUser = await _firestore.getPlayer(
      player!.uid,
      forceRefresh: true,
    );
    if (updatedUser != null) {
      player = updatedUser;
    }

    // Do NOT manually mutate bnplPlans — the Firestore stream
    // (streamBnplPlans) will automatically push the updated list.
    notifyListeners();
    return result;
  }


  /// Trigger a disaster event — refined logic.
  int triggerDisaster(DisasterType type) {
    activeDisaster = type;
    var destroyedCount = 0;
    double totalPayout = 0;

    InsuranceType? targetInsurance;
    if (type == DisasterType.flood) targetInsurance = InsuranceType.flood;
    if (type == DisasterType.storm) targetInsurance = InsuranceType.storm;
    if (type == DisasterType.drought) targetInsurance = InsuranceType.drought;

    final hasInsurance = player?.insurances.any((i) => i.type == targetInsurance && !i.isClaimed) ?? false;

    for (final row in grid) {
      for (final tile in row) {
        if (tile.hasCrop) {
          final config = kCropConfig[tile.crop!]!;
          final seedCost = config['seedCost'] as double;
          final sellPrice = config['sellPrice'] as double;
          
          if (type == DisasterType.flood) {
            isFlooded = true;
            tile.destroyCrop();
            destroyedCount++;
            if (hasInsurance) {
              totalPayout += seedCost + (sellPrice - seedCost) * 0.8;
            }
          } else if (type == DisasterType.storm) {
            // Storm destroys 70% of crops randomly
            if (_random.nextDouble() < 0.7) {
              tile.destroyCrop();
              destroyedCount++;
              if (hasInsurance) {
                totalPayout += seedCost + (sellPrice - seedCost) * 0.8;
              }
            }
          } else if (type == DisasterType.drought) {
            // Downgrade to initial state
            tile.growthStage = 1;
            tile.farmState = FarmPlotState.growing;
            if (hasInsurance) {
              // Payout for drought is lower since crops aren't destroyed
              totalPayout += (sellPrice - seedCost) * 0.3;
            }
          }
        }
      }
    }

    if (totalPayout > 0 && player != null) {
      totalPayout = totalPayout.roundToDouble();
      player!.deposit(totalPayout, method: PaymentMethod.bank);
      addNotification('Insurance Payout: ${totalPayout.toInt()}', icon: Icons.monetization_on, color: Colors.green);
      
      // Mark insurance as claimed (optional, usually they are for the whole period)
      // For this game, let's keep it simple: one payout per disaster event.
    }

    // Sync crop sprites
    game?.syncCropsFromGameState();
    game?.updateWeatherVisuals(type);
    notifyListeners();
    _saveGridState();
    _savePlayerState();
    _maybeGenerateDisasterQuest(type);
    return destroyedCount;
  }

  /// Clear the active disaster.
  void clearDisaster() {
    activeDisaster = DisasterType.none;
    game?.updateWeatherVisuals(DisasterType.none);
    notifyListeners();
  }

  /// Auto-generate an urgent market demand quest when a disaster hits.
  Future<void> _maybeGenerateDisasterQuest(DisasterType type) async {
    if (activeQuest != null || player == null || type == DisasterType.none) return;

    const contexts = {
      DisasterType.flood:   'A flood has devastated nearby paddy fields — rice is scarce!',
      DisasterType.storm:   'A storm in the neighboring realm ruined their wheat harvest!',
      DisasterType.drought: 'A drought is drying up corn supplies across the region!',
    };

    final quest = await GeminiService().generateQuest(
      player: player!,
      currentDay: currentDay,
      activeBnplCount: bnplPlans.length,
      disasterContext: contexts[type],
    );

    activeQuest = quest;
    notifyListeners();
  }

  // Camera control is now handled by Flame's CameraComponent in RichiFarmGame.

  /// Convert grass tile to farmland (e.g., after buying land via loan).
  bool convertToFarmland(int col, int row) {
    if (col < 0 || col >= kGridCols || row < 0 || row >= kGridRows) return false;
    final tile = grid[row][col];
    if (tile.type != TileType.grass) return false;
    tile.type = TileType.farmland;
    tile.farmState = FarmPlotState.idle;
    notifyListeners();
    return true;
  }

  /// Notify listeners that state has changed (called from UI after external mutation).
  void refresh() {
    notifyListeners();
  }

  // ── Bank Logic ───────────────────────────────────────────────

  void _processInterestsAndMaturity() {
    if (player == null) return;

    // 1. Savings Interest (1% daily)
    if (player!.bankRegistered && player!.bankBalance > 0) {
      final interest = (player!.bankBalance * 0.01).roundToDouble();
      player!.bankBalance += interest;
      _addMonthlyIncome(interest);
      
      // Log interest transaction
      _firestore.addTransaction(player!.uid, Transaction(
        id: '',
        paymentType: TransactionType.bank,
        amount: interest,
        category: TransactionCategory.other,
        timestamp: DateTime.now(),
        description: 'Daily Savings Interest (1%)',
      ));
    }

    // 2. Fixed Deposit Maturity
    final matured = <FixedDeposit>[];
    for (final fd in player!.fixedDeposits) {
      if (!fd.isMatured && currentDay >= fd.endDay) {
        fd.isMatured = true;
        final totalValue = (fd.principal * (1 + fd.interestRate)).roundToDouble();
        player!.bankBalance += totalValue;
        matured.add(fd);

        _addMonthlyIncome(totalValue - fd.principal);
        
        // Log maturity transaction
        _firestore.addTransaction(player!.uid, Transaction(
          id: '',
          paymentType: TransactionType.bank,
          amount: totalValue,
          category: TransactionCategory.other,
          timestamp: DateTime.now(),
          description: 'Fixed Deposit Matured: ${fd.durationMonths} Month(s)',
        ));
      }
    }

    // Remove matured fixed deposits from the active list
    player!.fixedDeposits.removeWhere((fd) => matured.contains(fd));

    if (matured.isNotEmpty) {
      addNotification('Fixed Deposit(s) Matured!', icon: Icons.account_balance_wallet, color: Colors.blue.shade900);
    }

    _savePlayerState();
    notifyListeners();
  }

  Future<bool> buyInsurance(InsuranceType type, double price) async {
    if (player == null) return false;
    
    if (player!.cashBalance < price && player!.bankBalance < price) return false;
    
    if (player!.cashBalance >= price) {
      player!.pay(price, method: PaymentMethod.cash);
    } else {
      player!.pay(price, method: PaymentMethod.bank);
    }

    final existingIndex = player!.insurances.indexWhere((i) => i.type == type);
    if (existingIndex != -1) {
      final existing = player!.insurances[existingIndex];
      player!.insurances[existingIndex] = Insurance(
        id: existing.id,
        type: existing.type,
        premium: existing.premium + price,
        expiryDay: existing.expiryDay + 30,
        isClaimed: existing.isClaimed,
      );
    } else {
      final insurance = Insurance(
        id: 'ins-${DateTime.now().millisecondsSinceEpoch}-${type.name}',
        type: type,
        premium: price,
        expiryDay: currentDay + 30,
      );
      player!.insurances.add(insurance);
    }
    
    await _savePlayerState();
    notifyListeners();
    return true;
  }

  Future<bool> buyComprehensiveInsurance(double totalPrice) async {
    if (player == null) return false;
    
    if (player!.cashBalance < totalPrice && player!.bankBalance < totalPrice) return false;
    
    if (player!.cashBalance >= totalPrice) {
      player!.pay(totalPrice, method: PaymentMethod.cash);
    } else {
      player!.pay(totalPrice, method: PaymentMethod.bank);
    }

    final expiry = currentDay + 30;
    final pricePerType = totalPrice / 3;

    player!.insurances.addAll([
      Insurance(id: 'ins-${DateTime.now().millisecondsSinceEpoch}-f', type: InsuranceType.flood, premium: pricePerType, expiryDay: expiry),
      Insurance(id: 'ins-${DateTime.now().millisecondsSinceEpoch}-s', type: InsuranceType.storm, premium: pricePerType, expiryDay: expiry),
      Insurance(id: 'ins-${DateTime.now().millisecondsSinceEpoch}-d', type: InsuranceType.drought, premium: pricePerType, expiryDay: expiry),
    ]);
    
    await _savePlayerState();
    notifyListeners();
    return true;
  }

  Future<void> cancelInsurance(String insuranceId) async {
    if (player == null) return;
    player!.insurances.removeWhere((i) => i.id == insuranceId);
    await _savePlayerState();
    notifyListeners();
  }

  Future<bool> createFixedDeposit(double amount, int months) async {
    if (player == null || amount < 100) return false;

    // Interest rates: 1m: 5%, 3m: 10%, 6m: 15%
    double rate = 0;
    if (months == 1) rate = 0.05;
    else if (months == 3) rate = 0.10;
    else if (months == 6) rate = 0.15;
    else return false;

    // Try to pay from cash or bank
    bool paid = false;
    if (player!.cashBalance >= amount) {
      player!.pay(amount, method: PaymentMethod.cash);
      paid = true;
    } else if (player!.bankBalance >= amount) {
      player!.pay(amount, method: PaymentMethod.bank);
      paid = true;
    }

    if (!paid) return false;

    final fd = FixedDeposit(
      id: 'fd-${DateTime.now().millisecondsSinceEpoch}',
      principal: amount,
      interestRate: rate,
      durationMonths: months,
      startDay: currentDay,
      endDay: currentDay + (months * kGameDaysPerMonth),
    );

    player!.fixedDeposits.add(fd);
    
    try {
      await _savePlayerState();
      notifyListeners();
      return true;
    } catch (e) {
      // Revert payment
      player!.deposit(amount, method: PaymentMethod.bank);
      return false;
    }
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

class NotificationItem {
  final String id = DateTime.now().millisecondsSinceEpoch.toString();
  final String message;
  final IconData icon;
  final Color color;
  NotificationItem({required this.message, required this.icon, required this.color});
}
