import 'dart:developer' as developer;

import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';

/// A Shady Lender character placed on the farm map.
///
/// Renders a single static frame from `assets/images/shady_lender.png`
/// (the middle frame of the first row — standard standing pose).
class ShadyLenderComponent extends SpriteComponent with HasGameRef<RichiFarmGame> {
  ShadyLenderComponent({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      final image = await game.images.load('shady_lender.png');
      final frameWidth = image.width / 3;
      final frameHeight = image.height / 4;

      // Pick the middle frame of the first row (standing pose).
      sprite = Sprite(
        image,
        srcPosition: Vector2(frameWidth, 0),
        srcSize: Vector2(frameWidth, frameHeight),
      );

      // Match component size to the cropped frame size.
      size = Vector2(frameWidth, frameHeight);
    } catch (e) {
      developer.log(
        'Failed to load ShadyLender sprite: shady_lender.png — $e',
        name: 'ShadyLenderComponent',
      );
    }

    // Render above crops (1) but below player (10).
    priority = 5;

    add(RectangleHitbox());
  }

  /// Check if a world-space point is inside this component's bounds.
  bool containsWorldPoint(double worldX, double worldY) {
    return worldX >= position.x &&
        worldX <= position.x + size.x &&
        worldY >= position.y &&
        worldY <= position.y + size.y;
  }
}
