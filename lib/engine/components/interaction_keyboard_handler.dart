import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'package:farm_fintech/engine/richi_farm_game.dart';
import 'package:farm_fintech/providers/game_state.dart';

class InteractionKeyboardHandler extends Component
    with KeyboardHandler, HasGameReference<RichiFarmGame> {
  
  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is! KeyDownEvent) return true; // Only handle key down

    final gameState = game.gameState;

    if (keysPressed.contains(LogicalKeyboardKey.digit1) || 
        keysPressed.contains(LogicalKeyboardKey.keyF)) {
      
      if (keysPressed.contains(LogicalKeyboardKey.keyF)) {
        print('F key pressed');
        final lender = game.shadyLender;
        final player = game.playerComponent;
        
        if (lender != null && player != null) {
          final dist = (player.position - lender.position).length;
          print('Distance to ShadyLender: $dist');
        } else {
          print('Lender or Player is NULL: lender=$lender, player=$player');
        }
        
        if (player != null && lender != null) {
          final px = player.position.x;
          final py = player.position.y;
          final lx = lender.position.x + lender.size.x / 2;
          final ly = lender.position.y + lender.size.y / 2;
          final dx = px - lx;
          final dy = py - ly;
          final distSq = dx * dx + dy * dy;

          // Check if distance is within interactable range (e.g., 64 pixels)
          if (distSq < 64 * 64) {
            game.overlays.add('ShadyLenderMenu');
            return true;
          }
        }
      }

      gameState.handleInteractionKey(1);
    } else if (keysPressed.contains(LogicalKeyboardKey.digit2)) {
      gameState.handleInteractionKey(2);
    } else if (keysPressed.contains(LogicalKeyboardKey.digit3)) {
      gameState.handleInteractionKey(3);
    } else if (keysPressed.contains(LogicalKeyboardKey.escape)) {
      gameState.setInteractionMenuState(InteractionMenuState.main);
    }

    return true;
  }
}
