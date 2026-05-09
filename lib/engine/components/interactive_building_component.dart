import 'dart:developer' as developer;

import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/services.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';

/// A building loaded from Tiled that the player can interact with.
///
/// Loads its sprite from `assets/images/{type}.png` dynamically.
/// Adds a `RectangleHitbox` and listens to the F key for interaction.
class InteractiveBuildingComponent extends SpriteComponent
    with HasGameRef<RichiFarmGame>, KeyboardHandler {
  final String type;

  InteractiveBuildingComponent({
    required this.type,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      sprite = await Sprite.load('$type.png');
    } catch (e) {
      developer.log(
        'Failed to load interactive building sprite: $type.png — $e',
        name: 'InteractiveBuildingComponent',
      );
    }

    // Render above crops (1) but below player (10).
    priority = 5;

    // Add hitbox for collision if needed, and for semantic correctness
    add(RectangleHitbox(size: size));
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent) return true;

    if (keysPressed.contains(LogicalKeyboardKey.keyF)) {
      final player = game.playerComponent;
      if (player != null) {
        final px = player.position.x;
        final py = player.position.y;
        final bx = position.x + size.x / 2;
        final by = position.y + size.y / 2;
        
        final dx = px - bx;
        final dy = py - by;
        final distSq = dx * dx + dy * dy;

        // Check if player is near the building (radius ~80 pixels)
        // You might need a larger radius if the building is large.
        // Or check distance from player to bounding box.
        // Let's use distance to bounding box for accuracy with large buildings.
        double nearestX = px.clamp(position.x, position.x + size.x);
        double nearestY = py.clamp(position.y, position.y + size.y);
        double distToBoxSq = (px - nearestX) * (px - nearestX) + (py - nearestY) * (py - nearestY);

        if (distToBoxSq <= 50 * 50) {
          if (type == 'bank' || type == 'merchant' || type == 'house') {
            developer.log('Interacting with $type', name: 'InteractiveBuildingComponent');
            game.onBuildingTapped?.call(type);
            return false; // Consume event
          }
        }
      }
    }
    return true; // Let other handlers process the key
  }

  /// Check if a world-space point is inside this component's bounds.
  bool containsWorldPoint(double worldX, double worldY) {
    return worldX >= position.x &&
        worldX <= position.x + size.x &&
        worldY >= position.y &&
        worldY <= position.y + size.y;
  }
}

