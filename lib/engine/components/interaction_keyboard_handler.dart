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

    if (keysPressed.contains(LogicalKeyboardKey.digit1)) {
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
