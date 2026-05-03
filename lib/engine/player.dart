import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/services.dart';

import 'richi_farm_game.dart';

// Define the different states your character can be in
enum PlayerState { walkDown, walkUp, walkLeft, walkRight, idleDown, idleUp, idleLeft, idleRight }

class Player extends SpriteAnimationGroupComponent<PlayerState> with HasGameReference<RichiFarmGame>, KeyboardHandler {
  Player() : super(size: Vector2(32, 32)); // Adjust size based on your pixel art

  // Movement speed in pixels per second
  static const double speed = 100.0;

  int horizontalDirection = 0;
  int verticalDirection = 0;

  @override
  Future<void> onLoad() async {
    // 1. Load the sprite sheet image
    final walkImage = await game.images.load('cat_walk.png');

    // 2. Define the grid details (your image has 4 columns and 4 rows)
    final spriteSheet = SpriteSheet(
      image: walkImage,
      srcSize: Vector2(48, 48), // The width/height of a single frame
    );

    
    // 3. Slice the sheet into specific animations
    // We increased stepTime to 0.6 so the idle is a slow breathe, not a fast flicker
    final idleDown = spriteSheet.createAnimation(row: 0, stepTime: 0.6, from: 0, to: 2);
    final idleUp = spriteSheet.createAnimation(row: 1, stepTime: 0.6, from: 0, to: 2);
    // FIXED: Row 2 is Right, Row 3 is Left
    final idleRight = spriteSheet.createAnimation(row: 3, stepTime: 0.6, from: 0, to: 2); 
    final idleLeft = spriteSheet.createAnimation(row: 2, stepTime: 0.6, from: 0, to: 2);  

    // Walk animations
    final walkDown = spriteSheet.createAnimation(row: 0, stepTime: 0.15, from: 2, to: 4);
    final walkUp = spriteSheet.createAnimation(row: 1, stepTime: 0.15, from: 2, to: 4);
    // FIXED: Row 2 is Right, Row 3 is Left
    final walkRight = spriteSheet.createAnimation(row: 3, stepTime: 0.15, from: 2, to: 4); 
    final walkLeft = spriteSheet.createAnimation(row: 2, stepTime: 0.15, from: 2, to: 4);

    // 4. Map the states to the animations
    animations = {
      PlayerState.walkDown: walkDown,
      PlayerState.walkUp: walkUp,
      PlayerState.walkLeft: walkLeft,
      PlayerState.walkRight: walkRight,
      PlayerState.idleDown: idleDown,
      PlayerState.idleUp: idleUp,
      PlayerState.idleLeft: idleLeft,
      PlayerState.idleRight: idleRight,
    };

    // Set the starting state (Default front)
    current = PlayerState.idleDown;
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    horizontalDirection = 0;
    verticalDirection = 0;

    if (keysPressed.contains(LogicalKeyboardKey.keyA)) {
      horizontalDirection -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyD)) {
      horizontalDirection += 1;
    }
    
    if (keysPressed.contains(LogicalKeyboardKey.keyW)) {
      verticalDirection -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyS)) {
      verticalDirection += 1;
    }
    
    return true; // Event handled
  }

  @override
  void update(double dt) {
    if (horizontalDirection == 0 && verticalDirection == 0) {
      // Not moving, set to idle based on last direction
      if (current == PlayerState.walkDown) {
        current = PlayerState.idleDown;
      } else if (current == PlayerState.walkUp) {
        current = PlayerState.idleUp;
      } else if (current == PlayerState.walkLeft) {
        current = PlayerState.idleLeft;
      } else if (current == PlayerState.walkRight) {
        current = PlayerState.idleRight;
      }
    } else {
      // Moving
      final direction = Vector2(horizontalDirection.toDouble(), verticalDirection.toDouble());
      if (direction.length > 0) {
        direction.normalize();
      }
      
      position.add(direction * speed * dt);

      // Update animation state based on movement direction
      if (direction.x.abs() > direction.y.abs()) {
        current = direction.x > 0 ? PlayerState.walkRight : PlayerState.walkLeft;
      } else {
        current = direction.y > 0 ? PlayerState.walkDown : PlayerState.walkUp;
      }
    }

    super.update(dt);
  }
}
