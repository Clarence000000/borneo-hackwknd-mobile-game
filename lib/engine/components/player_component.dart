import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/services.dart';

import 'package:farm_fintech/engine/richi_farm_game.dart';
import 'package:farm_fintech/engine/components/building_component.dart';

/// Character animation states (idle + walk × 4 directions).
enum PlayerState {
  walkDown,
  walkUp,
  walkLeft,
  walkRight,
  idleDown,
  idleUp,
  idleLeft,
  idleRight,
}

/// A movable player character on the farm map.
///
/// Uses [SpriteAnimationGroupComponent] to animate directional walk/idle
/// from the `cat_walk.png` spritesheet (4 rows × 4 columns, 48×48 frames).
///
/// Controls: WASD / Arrow keys + Joystick.
class PlayerComponent extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameReference<RichiFarmGame>, KeyboardHandler {
  static const double speed = 100.0; // pixels per second

  /// Map pixel bounds for clamping.
  double mapWidth = 0;
  double mapHeight = 0;

  // Keyboard input state.
  int _horizontalDirection = 0;
  int _verticalDirection = 0;

  PlayerComponent() : super(size: Vector2(48, 48));

  @override
  Future<void> onLoad() async {
    // 1. Load the sprite sheet image
    final walkImage = await game.images.load('cat_walk.png');

    // 2. Define the grid (4 columns × 4 rows, 48×48 per frame)
    final spriteSheet = SpriteSheet(
      image: walkImage,
      srcSize: Vector2(48, 48),
    );

    // 3. Slice into idle + walk animations
    final idleDown = spriteSheet.createAnimation(
      row: 0, stepTime: 0.6, from: 0, to: 2,
    );
    final idleUp = spriteSheet.createAnimation(
      row: 1, stepTime: 0.6, from: 0, to: 2,
    );
    // Row 2 is Right, Row 3 is Left (sprite sheet layout)
    final idleRight = spriteSheet.createAnimation(
      row: 3, stepTime: 0.6, from: 0, to: 2,
    );
    final idleLeft = spriteSheet.createAnimation(
      row: 2, stepTime: 0.6, from: 0, to: 2,
    );

    final walkDown = spriteSheet.createAnimation(
      row: 0, stepTime: 0.15, from: 2, to: 4,
    );
    final walkUp = spriteSheet.createAnimation(
      row: 1, stepTime: 0.15, from: 2, to: 4,
    );
    final walkRight = spriteSheet.createAnimation(
      row: 3, stepTime: 0.15, from: 2, to: 4,
    );
    final walkLeft = spriteSheet.createAnimation(
      row: 2, stepTime: 0.15, from: 2, to: 4,
    );

    // 4. Map states → animations
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

    current = PlayerState.idleDown;
    anchor = Anchor.center;
    priority = 10; // Render on top of crops
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _horizontalDirection = 0;
    _verticalDirection = 0;

    if (keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      _horizontalDirection -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      _horizontalDirection += 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyW) ||
        keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
      _verticalDirection -= 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyS) ||
        keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
      _verticalDirection += 1;
    }

    return true;
  }

  @override
  void update(double dt) {
    var dx = _horizontalDirection.toDouble();
    var dy = _verticalDirection.toDouble();

    // If no keyboard input, check joystick
    if (dx == 0 && dy == 0 && game.joystick != null &&
        game.joystick!.direction != JoystickDirection.idle) {
      dx = game.joystick!.relativeDelta.x;
      dy = game.joystick!.relativeDelta.y;
    }

    if (dx == 0 && dy == 0) {
      // Not moving → idle based on last walk direction
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
      // Moving → normalize and apply
      final direction = Vector2(dx, dy);
      if (direction.length > 0) {
        direction.normalize();
      }

      // Check collision at feet (center-bottom)
      final feetOffset = Vector2(0, 16);
      
      final moveX = direction.x * speed * dt;
      final moveY = direction.y * speed * dt;
      
      if (moveX != 0) {
        final currentFeet = position + feetOffset;
        final newFeetX = currentFeet..x += moveX;
        if (!_isCollision(newFeetX)) {
          position.x += moveX;
        }
      }
      
      if (moveY != 0) {
        final currentFeet = position + feetOffset;
        final newFeetY = currentFeet..y += moveY;
        if (!_isCollision(newFeetY)) {
          position.y += moveY;
        }
      }

      // Pick animation based on dominant axis
      if (dx.abs() > dy.abs()) {
        current = dx > 0 ? PlayerState.walkRight : PlayerState.walkLeft;
      } else {
        current = dy > 0 ? PlayerState.walkDown : PlayerState.walkUp;
      }
    }

    // Clamp to map bounds (fallback)
    if (mapWidth > 0 && mapHeight > 0) {
      position.x = position.x.clamp(0, mapWidth);
      position.y = position.y.clamp(0, mapHeight);
    }

    // Proximity detection for crops and buildings
    _updateInteractables();

    super.update(dt);
  }

  void _updateInteractables() {
    final grid = game.gameState.grid;
    final mapCol = (position.x / 16).floor();
    final mapRow = (position.y / 16).floor();
    
    // 1. Check building proximity
    BuildingComponent? closestBuilding;
    double minBldgDistSq = double.infinity;
    // Buildings are usually large, check distance to bounding box center or just edges.
    for (final building in game.buildings) {
      // Find center of building
      final bx = building.position.x + building.size.x / 2;
      final by = building.position.y + building.size.y / 2;
      final dx = position.x - bx;
      final dy = position.y - by;
      final distSq = dx * dx + dy * dy;
      
      // Interaction radius for buildings: slightly larger (e.g. 48 pixels ~ 3 tiles from center)
      if (distSq < 48 * 48 && distSq < minBldgDistSq) {
        minBldgDistSq = distSq;
        closestBuilding = building;
      }
    }
    game.gameState.updateInteractableBuilding(closestBuilding);

    // If near a building, we probably don't want to interact with a tile.
    if (closestBuilding != null) {
      game.gameState.updateInteractableTile(null);
      return;
    }

    // 2. Check crop proximity
    (int, int)? closestTile;
    double minDistanceSq = double.infinity;
    // Search radius: 2 tiles
    for (int r = mapRow - 2; r <= mapRow + 2; r++) {
      for (int c = mapCol - 2; c <= mapCol + 2; c++) {
        if (r >= 0 && r < grid.length && c >= 0 && c < grid[0].length) {
          final tile = grid[r][c];
          if (tile.isFarmland) {
            final tileX = c * 16.0 + 8.0;
            final tileY = r * 16.0 + 8.0;
            final dx = position.x - tileX;
            final dy = position.y - tileY;
            final distSq = dx * dx + dy * dy;
            
            // Interaction radius: 24 pixels (1.5 tiles)
            if (distSq < 24 * 24 && distSq < minDistanceSq) {
              minDistanceSq = distSq;
              closestTile = (c, r);
            }
          }
        }
      }
    }
    
    game.gameState.updateInteractableTile(closestTile);
  }

  bool _isCollision(Vector2 testPos) {
    if (mapWidth > 0 && mapHeight > 0) {
      if (testPos.x < 0 || testPos.x > mapWidth || testPos.y < 0 || testPos.y > mapHeight) {
        return true;
      }
    }

    for (final building in game.buildings) {
      if (building.containsWorldPoint(testPos.x, testPos.y)) {
        return true;
      }
    }

    final col = (testPos.x / 16).floor();
    final row = (testPos.y / 16).floor();

    final grid = game.gameState.grid;
    if (row >= 0 && row < grid.length && col >= 0 && col < grid[0].length) {
      // Farmland is now crossable, so we don't return true here.
    }

    try {
      final mapComp = game.mapComponent;
      if (mapComp == null) return false;
      final map = mapComp.tileMap.map;
      for (final layer in map.layers) {
        if (layer.name == 'Water' || layer.name == 'Hills') {
          final layerDyn = layer as dynamic;
          final data = layerDyn.data;
          if (data != null) {
            final idx = row * map.width + col;
            if (idx >= 0 && idx < data.length) {
              final gid = data[idx] as int? ?? 0;
              if (gid != 0) return true;
            }
          }
        }
      }
    } catch (_) {}

    return false;
  }
}
