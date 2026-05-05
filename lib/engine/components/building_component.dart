import 'dart:developer' as developer;

import 'package:flame/components.dart';

/// Type of building on the map.
enum BuildingType { bank, merchant }

/// A static building placed on the farm map.
///
/// Loads its sprite from `assets/images/{type}.png` and occupies a rectangular
/// area on the map. When tapped (detected via hit-test in [RichiFarmGame]),
/// triggers navigation to the corresponding screen.
class BuildingComponent extends SpriteComponent {
  final BuildingType buildingType;
  final int gridCol;
  final int gridRow;

  BuildingComponent({
    required this.buildingType,
    required this.gridCol,
    required this.gridRow,
    required Vector2 buildingSize,
  }) : super(size: buildingSize);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final imagePath = _imagePath(buildingType);
    try {
      sprite = await Sprite.load(imagePath);
    } catch (e) {
      developer.log(
        'Failed to load building sprite: $imagePath — $e',
        name: 'BuildingComponent',
      );
    }

    // Position: top-left corner at tile coordinates.
    position = Vector2(gridCol * 16.0, gridRow * 16.0);

    // Render above crops (1) but below player (10).
    priority = 5;
  }

  /// Check if a world-space point is inside this building's bounds.
  bool containsWorldPoint(double worldX, double worldY) {
    return worldX >= position.x &&
        worldX <= position.x + size.x &&
        worldY >= position.y &&
        worldY <= position.y + size.y;
  }

  static String _imagePath(BuildingType type) {
    switch (type) {
      case BuildingType.bank:
        return 'bank.png';
      case BuildingType.merchant:
        return 'merchant.png';
    }
  }
}
