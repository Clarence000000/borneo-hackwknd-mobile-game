import 'dart:developer' as developer;

import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';

/// A Shady Lender character placed on the farm map.
///
/// Loads its sprite from `assets/images/shady_lender.png` and occupies a rectangular
/// area on the map.
class ShadyLenderComponent extends SpriteAnimationComponent with HasGameRef<RichiFarmGame> {
  ShadyLenderComponent({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      final image = await game.images.load('shady_lender.png');
      final textureSize = Vector2(image.width / 3, image.height / 4);

      animation = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: 3,
          stepTime: 0.2,
          textureSize: textureSize,
        ),
      );

      // Ensure the component size matches the texture size
      size = textureSize;
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
