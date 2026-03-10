import 'package:farm_fintech/config/constants.dart';

/// Represents a single tile on the isometric grid.
class Tile {
  final int col;
  final int row;
  TileType type;
  CropType? crop;
  int growthStage; // 0=seed, 1=sprout, 2=growing, 3=harvestable
  DateTime? plantedAt;
  bool insured;

  Tile({
    required this.col,
    required this.row,
    this.type = TileType.grass,
    this.crop,
    this.growthStage = 0,
    this.plantedAt,
    this.insured = false,
  });

  bool get isEmpty => type == TileType.grass && crop == null;
  bool get hasCrop => crop != null;
  bool get isHarvestable => hasCrop && growthStage >= 3;
  bool get isFarmland => type == TileType.farmland;

  /// Plant a crop on this tile. Tile must be farmland and empty.
  bool plant(CropType cropType) {
    if (!isFarmland || hasCrop) return false;
    crop = cropType;
    growthStage = 0;
    plantedAt = DateTime.now();
    return true;
  }

  /// Harvest the crop. Returns the crop type or null if not harvestable.
  CropType? harvest() {
    if (!isHarvestable) return null;
    final harvested = crop;
    crop = null;
    growthStage = 0;
    plantedAt = null;
    return harvested;
  }

  /// Destroy crop (e.g., from disaster).
  void destroyCrop() {
    crop = null;
    growthStage = 0;
    plantedAt = null;
  }

  /// Convert to/from Firestore map.
  Map<String, dynamic> toMap() => {
        'col': col,
        'row': row,
        'type': type.name,
        'crop': crop?.name,
        'growthStage': growthStage,
        'plantedAt': plantedAt?.millisecondsSinceEpoch,
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
        insured: map['insured'] as bool? ?? false,
      );
}

enum TileType {
  grass,
  farmland,
  water,
  building,
}
