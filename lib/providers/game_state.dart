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
  List<Loan> loans = [];
  List<Insurance> insurances = [];

  // ── Game Day ────────────────────────────────────────────────
  int currentDay = 1;

  // ── Crop selection for planting ─────────────────────────────
  CropType? selectedCropToPlant;

  GameState() {
    _initGrid();
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
      return null;
    }
  }

  Future<bool> buyEquipment(double amount, PaymentMethod method) async {
    if (player == null) return false;

    final previousCashBalance = player!.cashBalance;
    final previousBankBalance = player!.bankBalance;
    final didPay = player!.pay(amount, method: method);
    if (!didPay) return false;

    try {
      await _savePlayerState();
      notifyListeners();
      return true;
    } catch (_) {
      player!.cashBalance = previousCashBalance;
      player!.bankBalance = previousBankBalance;
      return false;
    }
  }

  /// Advance the game by one day. Grows crops, checks BNPL dues via Cloud, etc.
  Future<void> advanceDay() async {
    currentDay++;

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

    notifyListeners();

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
          final result = await _cloud.calculateBnplPenalty(plan.id);
          // If a penalty was applied or defaulted, it modified the user wallet in Firestore
          if (result['penalty'] != null && result['penalty'] > 0) {
            needsRefresh = true;
          }
        }
      }

      // If the server altered our wallet, fetch fresh state
      if (needsRefresh) {
        final updatedUser = await _firestore.getPlayer(player!.uid);
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
