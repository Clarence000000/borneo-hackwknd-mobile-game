import 'dart:developer' as developer;

import 'package:flame/components.dart';
import 'package:farm_fintech/config/constants.dart';

/// A [SpriteComponent] that renders a crop at a specific tile position.
///
/// Loads its sprite from `assets/images/crops/{cropName}_{stage}.png`.
/// Call [updateStage] when the crop grows to swap the sprite.
class CropComponent extends SpriteComponent {
  final CropType cropType;
  final int gridCol;
  final int gridRow;
  int _currentStage;

  CropComponent({
    required this.cropType,
    required this.gridCol,
    required this.gridRow,
    int initialStage = 0,
  }) : _currentStage = initialStage.clamp(0, 3);

  int get currentStage => _currentStage;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    size = Vector2.all(16);
    position = Vector2(gridCol * 16.0, gridRow * 16.0);

    // Render on top of the map tiles but below buildings/player.
    priority = 1;

    await _loadSprite();
  }

  /// Swap the sprite to a new growth stage.
  Future<void> updateStage(int newStage) async {
    final clamped = newStage.clamp(0, 3);
    if (clamped == _currentStage) return;
    _currentStage = clamped;
    await _loadSprite();
  }

  Future<void> _loadSprite() async {
    final cropName = _cropName(cropType);
    final path = 'crops/${cropName}_$_currentStage.png';
    try {
      sprite = await Sprite.load(path);
    } catch (e) {
      developer.log(
        'Failed to load crop sprite: $path — $e',
        name: 'CropComponent',
      );
      // Leave sprite null — tile will show through
    }
  }

  static String _cropName(CropType c) {
    switch (c) {
      case CropType.wheat:
        return 'wheat';
      case CropType.rice:
        return 'rice';
      case CropType.corn:
        return 'corn';
    }
  }
}
