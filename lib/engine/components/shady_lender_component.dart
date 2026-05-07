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

      // New image is a single sprite — use the entire image.
      sprite = Sprite(image);

      // Fixed NPC tile size (Flame auto-scales the sprite to fit).
      size = Vector2(48, 48);
    } catch (e) {
      developer.log(
        'Failed to load ShadyLender sprite: shady_lender.png — $e',
        name: 'ShadyLenderComponent',
      );
    }

    // Render above crops (1) but below player (10).
    priority = 5;

    add(RectangleHitbox(size: Vector2(48, 48)));
  }

  /// Check if a world-space point is inside this component's bounds.
  bool containsWorldPoint(double worldX, double worldY) {
    return worldX >= position.x &&
        worldX <= position.x + size.x &&
        worldY >= position.y &&
        worldY <= position.y + size.y;
  }
}
