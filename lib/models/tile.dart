import 'package:farm_fintech/config/constants.dart';

/// Farm plot lifecycle state machine.
enum FarmPlotState { idle, planted, growing, ready }

/// Represents a single tile on the game grid.
class Tile {
  final int col;
  final int row;
  TileType type;
  CropType? crop;
  int growthStage; // 0=seed, 1=sprout, 2=growing, 3=harvestable
  DateTime? plantedAt;
  int? plantedDay; // In-game day when crop was planted
  int? readyDay; // In-game day when crop became harvestable
  bool insured;

  // ── Farm plot lifecycle fields ──────────────────────────────
  FarmPlotState farmState;
  int witherAfterDays;
  bool allowWither;

  Tile({
    required this.col,
    required this.row,
    this.type = TileType.grass,
    this.crop,
    this.growthStage = 0,
    this.plantedAt,
    this.plantedDay,
    this.readyDay,
    this.insured = false,
    this.farmState = FarmPlotState.idle,
    this.witherAfterDays = -1,
    this.allowWither = false,
  });

  bool get isEmpty => type == TileType.grass && crop == null;
  bool get hasCrop => crop != null;
  bool get isHarvestable => hasCrop && growthStage >= 3;
  bool get isFarmland => type == TileType.farmland;

  /// Plant a crop on this tile. Tile must be farmland and empty.
  bool plant(CropType cropType, {int? currentDay}) {
    if (!isFarmland || hasCrop) return false;
    crop = cropType;
    growthStage = 0;
    plantedAt = DateTime.now();
    plantedDay = currentDay;
    readyDay = null;
    farmState = FarmPlotState.planted;
    return true;
  }

  /// Harvest the crop. Returns the crop type or null if not harvestable.
  CropType? harvest() {
    if (!isHarvestable) return null;
    final harvested = crop;
    crop = null;
    growthStage = 0;
    plantedAt = null;
    plantedDay = null;
    readyDay = null;
    farmState = FarmPlotState.idle;
    return harvested;
  }

  /// Destroy crop (e.g., from disaster).
  void destroyCrop() {
    crop = null;
    growthStage = 0;
    plantedAt = null;
    plantedDay = null;
    readyDay = null;
    farmState = FarmPlotState.idle;
  }

  /// Advance the crop lifecycle by one in-game day.
  ///
  /// Uses [plantedDay] and [growthDays] to determine when the crop
  /// transitions from planted → growing → ready.
  void advanceLifecycle({required int currentDay, required int growthDays}) {
    if (crop == null) return;
    if (farmState == FarmPlotState.idle) return;

    if (plantedDay == null) {
      // Legacy: no plantedDay recorded, use simple increment
      if (growthStage < 3) {
        growthStage++;
        farmState =
            growthStage >= 3 ? FarmPlotState.ready : FarmPlotState.growing;
        if (growthStage >= 3) readyDay ??= currentDay;
      }
      return;
    }

    final elapsed = currentDay - plantedDay!;
    if (elapsed <= 0) return;

    // Map elapsed days to growth stages (0..3)
    final stagesPerDay = growthDays > 0 ? growthDays / 3.0 : 1.0;
    final newStage = (elapsed / stagesPerDay).floor().clamp(0, 3);

    if (newStage > growthStage) {
      growthStage = newStage;
    }

    if (growthStage >= 3) {
      farmState = FarmPlotState.ready;
      readyDay ??= currentDay;
    } else if (growthStage >= 1) {
      farmState = FarmPlotState.growing;
    } else {
      farmState = FarmPlotState.planted;
    }
  }

  /// Initialize farm plot from Tiled map properties.
  void setFarmStateFromTiled(
    FarmPlotState state, {
    CropType? cropType,
    int? stage,
    int? plantedDayValue,
    int? readyDayValue,
    int? witherDays,
    bool? witherEnabled,
    int? currentDay,
  }) {
    farmState = state;
    type = TileType.farmland;

    if (cropType != null) crop = cropType;
    if (stage != null) growthStage = stage.clamp(0, 3);
    if (plantedDayValue != null) plantedDay = plantedDayValue;
    if (readyDayValue != null) readyDay = readyDayValue;
    if (witherDays != null) witherAfterDays = witherDays;
    if (witherEnabled != null) allowWither = witherEnabled;

    // Auto-set farmState from growthStage if not explicitly set
    if (state == FarmPlotState.idle && crop != null) {
      if (growthStage >= 3) {
        farmState = FarmPlotState.ready;
        readyDay ??= currentDay;
      } else if (growthStage >= 1) {
        farmState = FarmPlotState.growing;
      } else {
        farmState = FarmPlotState.planted;
      }
    }
  }

  /// Convert to/from Firestore map.
  Map<String, dynamic> toMap() => {
    'col': col,
    'row': row,
    'type': type.name,
    'crop': crop?.name,
    'growthStage': growthStage,
    'plantedAt': plantedAt?.millisecondsSinceEpoch,
    'plantedDay': plantedDay,
    'readyDay': readyDay,
    'insured': insured,
    'farmState': farmState.name,
  };

  factory Tile.fromMap(Map<String, dynamic> map) {
    final tile = Tile(
      col: map['col'] as int,
      row: map['row'] as int,
      type: TileType.values.byName(map['type'] as String),
      crop:
          map['crop'] != null
              ? CropType.values.byName(map['crop'] as String)
              : null,
      growthStage: map['growthStage'] as int? ?? 0,
      plantedAt:
          map['plantedAt'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['plantedAt'] as int)
              : null,
      plantedDay: map['plantedDay'] as int?,
      readyDay: map['readyDay'] as int?,
      insured: map['insured'] as bool? ?? false,
    );
    // Restore farmState
    final stateStr = map['farmState'] as String?;
    if (stateStr != null) {
      try {
        tile.farmState = FarmPlotState.values.byName(stateStr);
      } catch (_) {}
    }
    return tile;
  }
}

enum TileType { grass, farmland, water, building }
