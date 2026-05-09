import 'dart:developer' as developer;
import 'package:flame/components.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';

/// An invisible portal zone that triggers map transitions when the player walks into it.
class PortalComponent extends PositionComponent with HasGameRef<RichiFarmGame> {
  final String targetMap;
  final String spawnPointName;

  PortalComponent({
    required this.targetMap,
    required this.spawnPointName,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  void update(double dt) {
    super.update(dt);
    
    final player = game.playerComponent;
    if (player != null) {
      // Check if player's feet (position + offset) is inside portal bounds
      final px = player.position.x;
      final py = player.position.y + 16; // Feet offset usually used in PlayerComponent

      if (px >= position.x && px <= position.x + size.x &&
          py >= position.y && py <= position.y + size.y) {
        // Trigger map transition if cooldown is over
        if (game.canUsePortal) {
          game.goToMap(targetMap, spawnPointName);
        }
      }
    }
  }
}
