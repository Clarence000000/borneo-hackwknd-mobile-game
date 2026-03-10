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

/// Central game state managed via [ChangeNotifier].
class GameState extends ChangeNotifier {
  final IsometricEngine engine = const IsometricEngine();
  final GameCamera camera = GameCamera();

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
      (row) => List.generate(
        kGridCols,
        (col) {
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
        },
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────

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
  bool plantCrop(CropType cropType) {
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

    // Deduct cost (prefer cash first)
    if (player!.cashBalance >= cost) {
      player!.pay(cost, method: PaymentMethod.cash);
    } else {
      player!.pay(cost, method: PaymentMethod.bank);
    }

    notifyListeners();
    return true;
  }

  /// Harvest the selected tile's crop.
  double? harvestCrop() {
    if (selectedTile == null || player == null) return null;

    final (col, row) = selectedTile!;
    final tile = grid[row][col];
    final harvested = tile.harvest();

    if (harvested == null) return null;

    final config = kCropConfig[harvested]!;
    final revenue = config['sellPrice'] as double;

    player!.deposit(revenue, method: PaymentMethod.cash);
    notifyListeners();
    return revenue;
  }

  /// Advance the game by one day. Grows crops, checks BNPL dues, etc.
  void advanceDay() {
    currentDay++;

    // Grow crops
    for (final row in grid) {
      for (final tile in row) {
        if (tile.hasCrop && tile.growthStage < 3) {
          final config = kCropConfig[tile.crop!]!;
          final growthDays = config['growthDays'] as int;
          final daysSincePlant = tile.plantedAt != null
              ? DateTime.now().difference(tile.plantedAt!).inDays
              : 0;

          // Simple growth: divide total growth time into 3 stages
          final stageInterval = growthDays ~/ 3;
          if (stageInterval > 0) {
            tile.growthStage =
                (daysSincePlant ~/ stageInterval).clamp(0, 3);
          }
        }
      }
    }

    // For hackathon demo: just increment growth stage directly
    for (final row in grid) {
      for (final tile in row) {
        if (tile.hasCrop && tile.growthStage < 3) {
          tile.growthStage++;
        }
      }
    }

    notifyListeners();
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
