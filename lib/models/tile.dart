import 'package:farm_fintech/config/constants.dart';

/// Represents a single tile on the isometric grid.
class Tile {
  final int col;
  final int row;
  TileType type;
  CropType? crop;
  int growthStage; // 0=seed, 1=sprout, 2=growing, 3=harvestable
  DateTime? plantedAt;
  int? plantedDay; // In-game day when crop was planted
  int? readyDay; // In-game day when plot reached Ready state
  int witherAfterDays;
  bool allowWither;
  FarmPlotState farmState;
  bool insured;

  Tile({
    required this.col,
    required this.row,
    this.type = TileType.grass,
    this.crop,
    this.growthStage = 0,
    this.plantedAt,
    this.plantedDay,
    this.readyDay,
    this.witherAfterDays = 2,
    this.allowWither = true,
    this.farmState = FarmPlotState.idle,
    this.insured = false,
  });

  bool get isEmpty => crop == null;
  bool get hasCrop => crop != null;
  bool get isHarvestable => hasCrop && farmState == FarmPlotState.ready;
  bool get isFarmland => type == TileType.farmland;
  bool get isWithered => false;
  bool get canPlant => isFarmland && farmState == FarmPlotState.idle;

  /// Plant a crop on this tile. Tile must be farmland and empty.
  bool plant(CropType cropType, {required int currentDay}) {
    if (!canPlant) return false;
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

  void clearWithered() {
    if (farmState != FarmPlotState.withered) return;
    crop = null;
    growthStage = 0;
    plantedAt = null;
    plantedDay = null;
    readyDay = null;
    farmState = FarmPlotState.idle;
  }

  /// Recalculate growth stage and farm plot state from current in-game day.
  void advanceLifecycle({required int currentDay, required int growthDays}) {
    if (!hasCrop) {
      farmState = FarmPlotState.idle;
      growthStage = 0;
      plantedDay = null;
      readyDay = null;
      return;
    }

    final daysSincePlant = plantedDay != null ? currentDay - plantedDay! : 0;

    final int computedStage;
    final stageInterval = growthDays ~/ 3;
    if (stageInterval > 0) {
      computedStage = (daysSincePlant ~/ stageInterval).clamp(0, 3);
    } else {
      computedStage = daysSincePlant.clamp(0, 3);
    }
    growthStage = computedStage;

    if (growthStage <= 0) {
      farmState = FarmPlotState.planted;
      readyDay = null;
      return;
    }

    if (growthStage < 3) {
      farmState = FarmPlotState.growing;
      readyDay = null;
      return;
    }

    if (readyDay == null) {
      readyDay = currentDay;
    }

    farmState = FarmPlotState.ready;
  }

  /// Force state from Tiled metadata while keeping model invariants.
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
    if (witherDays != null) {
      witherAfterDays = witherDays;
    }
    if (witherEnabled != null) {
      allowWither = witherEnabled;
    }

    if (cropType != null) {
      crop = cropType;
    }
    if (plantedDayValue != null) {
      plantedDay = plantedDayValue;
    }
    if (readyDayValue != null) {
      readyDay = readyDayValue;
    }

    switch (state) {
      case FarmPlotState.idle:
        destroyCrop();
        return;
      case FarmPlotState.planted:
        farmState = FarmPlotState.planted;
        growthStage = (stage ?? 0).clamp(0, 0);
        readyDay = null;
        break;
      case FarmPlotState.growing:
        farmState = FarmPlotState.growing;
        growthStage = (stage ?? 1).clamp(1, 2);
        readyDay = null;
        break;
      case FarmPlotState.ready:
        farmState = FarmPlotState.ready;
        growthStage = (stage ?? 3).clamp(3, 3);
        readyDay ??= currentDay;
        break;
      case FarmPlotState.withered:
        // Compatibility: old Tiled/saved data may still use `withered`.
        // Treat it as ready because withering is disabled.
        farmState = FarmPlotState.ready;
        growthStage = (stage ?? 3).clamp(3, 3);
        readyDay ??= currentDay;
        break;
    }

    if (!hasCrop && farmState != FarmPlotState.idle) {
      farmState = FarmPlotState.idle;
      growthStage = 0;
      plantedDay = null;
      readyDay = null;
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
    'witherAfterDays': witherAfterDays,
    'allowWither': allowWither,
    'farmState':
        (farmState == FarmPlotState.withered ? FarmPlotState.ready : farmState)
            .name,
    'insured': insured,
  };

  factory Tile.fromMap(Map<String, dynamic> map) => Tile(
    col: map['col'] as int,
    row: map['row'] as int,
    type: TileType.values.byName(map['type'] as String),
    crop: map['crop'] != null
        ? CropType.values.byName(map['crop'] as String)
        : null,
    growthStage: map['growthStage'] as int? ?? 0,
    plantedAt: map['plantedAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['plantedAt'] as int)
        : null,
    plantedDay: map['plantedDay'] as int?,
    readyDay: map['readyDay'] as int?,
    witherAfterDays: map['witherAfterDays'] as int? ?? 2,
    allowWither: map['allowWither'] as bool? ?? true,
    farmState: (() {
      final raw = map['farmState'] as String?;
      if (raw == null) return FarmPlotState.idle;
      final parsed = FarmPlotState.values.byName(raw);
      return parsed == FarmPlotState.withered ? FarmPlotState.ready : parsed;
    })(),
    insured: map['insured'] as bool? ?? false,
  );
}

enum TileType { grass, farmland, water, building }

enum FarmPlotState { idle, planted, growing, ready, withered }
