import 'dart:developer' as developer;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/components/player_component.dart';

/// Flame game for the house interior map (house_interior.tmx).
///
/// Loads the interior Tiled map, places the player near the door, and
/// calls [onExitDoor] when the player walks back onto the Door exit object.
class HouseInteriorGame extends FlameGame
    with PanDetector, HasKeyboardHandlerComponents {
  /// Called once when the player steps onto the Door exit area.
  void Function()? onExitDoor;

  late TiledComponent _mapComponent;
  late _InteriorPlayerComponent _player;
  JoystickComponent? joystick;

  late double _mapWidth;
  late double _mapHeight;

  /// Exit rectangle read from the TMX "Exits" object layer.
  Rect _doorRect = Rect.zero;
  bool _hasExited = false;

  @override
  Color backgroundColor() => GameColors.uiBackground;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _mapComponent = await TiledComponent.load(
      'house_interior.tmx',
      Vector2.all(16),
    );
    _mapComponent.priority = 0;
    world.add(_mapComponent);

    final map = _mapComponent.tileMap.map;
    _mapWidth = map.width * map.tileWidth.toDouble();
    _mapHeight = map.height * map.tileHeight.toDouble();

    _loadDoorRect(map);

    // Spawn player just above the door so entering feels natural.
    final spawnY = _doorRect != Rect.zero
        ? (_doorRect.top - 24).clamp(0.0, _mapHeight)
        : _mapHeight - 40;
    _player = _InteriorPlayerComponent();
    _player.position = Vector2(_mapWidth / 2, spawnY);
    _player.mapWidth = _mapWidth;
    _player.mapHeight = _mapHeight;
    world.add(_player);

    joystick = JoystickComponent(
      knob: CircleComponent(
        radius: 15,
        paint: Paint()..color = const Color(0xFFFFFFFF),
      ),
      background: CircleComponent(
        radius: 50,
        paint: Paint()..color = const Color(0x88FFFFFF),
      ),
      margin: const EdgeInsets.only(left: 40, bottom: 40),
    );
    camera.viewport.add(joystick!);

    _setupCamera();
  }

  void _loadDoorRect(dynamic map) {
    try {
      for (final layer in map.layers) {
        if ((layer.name as String?)?.toLowerCase() != 'exits') continue;
        for (final obj in (layer.objects as List)) {
          if ((obj.name as String?)?.toLowerCase() == 'door') {
            final x = (obj.x as num).toDouble();
            final y = (obj.y as num).toDouble();
            final w = (obj.width as num?)?.toDouble() ?? 16.0;
            final h = (obj.height as num?)?.toDouble() ?? 16.0;
            _doorRect = Rect.fromLTWH(x, y, w, h);
            developer.log('Door exit: $_doorRect', name: 'HouseInteriorGame');
            return;
          }
        }
      }
    } catch (e) {
      developer.log('_loadDoorRect error: $e', name: 'HouseInteriorGame');
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_hasExited && _doorRect != Rect.zero) {
      if (_doorRect.contains(Offset(_player.position.x, _player.position.y))) {
        _hasExited = true;
        onExitDoor?.call();
      }
    }
    // Camera follows player.
    camera.viewfinder.position = _player.position;
    _clampCamera();
  }

  void _setupCamera() {
    if (size.x <= 0 || size.y <= 0) return;
    final scaleX = size.x / _mapWidth;
    final scaleY = size.y / _mapHeight;
    camera.viewfinder.zoom = scaleX > scaleY ? scaleX : scaleY;
    camera.viewfinder.position = Vector2(_mapWidth / 2, _mapHeight / 2);
    _clampCamera();
  }

  void _clampCamera() {
    final zoom = camera.viewfinder.zoom;
    final halfViewW = (size.x / zoom) / 2;
    final halfViewH = (size.y / zoom) / 2;
    final minX = halfViewW;
    final maxX = _mapWidth - halfViewW;
    final minY = halfViewH;
    final maxY = _mapHeight - halfViewH;
    final pos = camera.viewfinder.position;
    pos.x = (minX >= maxX) ? _mapWidth / 2 : pos.x.clamp(minX, maxX);
    pos.y = (minY >= maxY) ? _mapHeight / 2 : pos.y.clamp(minY, maxY);
    camera.viewfinder.position = pos;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    final zoom = camera.viewfinder.zoom;
    camera.viewfinder.position -= info.delta.global / zoom;
    _clampCamera();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _setupCamera();
  }
}

/// Player for the house interior — movement only, no interactable detection.
/// References [HouseInteriorGame] and reuses [PlayerState] animations.
class _InteriorPlayerComponent
    extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameReference<HouseInteriorGame>, KeyboardHandler {
  static const double speed = 100.0;

  double mapWidth = 0;
  double mapHeight = 0;

  int _horizontalDirection = 0;
  int _verticalDirection = 0;

  _InteriorPlayerComponent() : super(size: Vector2(48, 48));

  @override
  Future<void> onLoad() async {
    final walkImage = await game.images.load('cat_walk.png');
    final sheet = SpriteSheet(image: walkImage, srcSize: Vector2(48, 48));

    animations = {
      PlayerState.idleDown:  sheet.createAnimation(row: 0, stepTime: 0.6,  from: 0, to: 2),
      PlayerState.idleUp:    sheet.createAnimation(row: 1, stepTime: 0.6,  from: 0, to: 2),
      PlayerState.idleLeft:  sheet.createAnimation(row: 2, stepTime: 0.6,  from: 0, to: 2),
      PlayerState.idleRight: sheet.createAnimation(row: 3, stepTime: 0.6,  from: 0, to: 2),
      PlayerState.walkDown:  sheet.createAnimation(row: 0, stepTime: 0.15, from: 2, to: 4),
      PlayerState.walkUp:    sheet.createAnimation(row: 1, stepTime: 0.15, from: 2, to: 4),
      PlayerState.walkLeft:  sheet.createAnimation(row: 2, stepTime: 0.15, from: 2, to: 4),
      PlayerState.walkRight: sheet.createAnimation(row: 3, stepTime: 0.15, from: 2, to: 4),
    };

    current = PlayerState.idleDown;
    anchor = Anchor.center;
    priority = 10;
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _horizontalDirection = 0;
    _verticalDirection = 0;
    if (keysPressed.contains(LogicalKeyboardKey.keyA) ||
        keysPressed.contains(LogicalKeyboardKey.arrowLeft)) { _horizontalDirection -= 1; }
    if (keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight)) { _horizontalDirection += 1; }
    if (keysPressed.contains(LogicalKeyboardKey.keyW) ||
        keysPressed.contains(LogicalKeyboardKey.arrowUp)) { _verticalDirection -= 1; }
    if (keysPressed.contains(LogicalKeyboardKey.keyS) ||
        keysPressed.contains(LogicalKeyboardKey.arrowDown)) { _verticalDirection += 1; }
    return true;
  }

  @override
  void update(double dt) {
    var dx = _horizontalDirection.toDouble();
    var dy = _verticalDirection.toDouble();

    if (dx == 0 && dy == 0 &&
        game.joystick != null &&
        game.joystick!.direction != JoystickDirection.idle) {
      dx = game.joystick!.relativeDelta.x;
      dy = game.joystick!.relativeDelta.y;
    }

    if (dx == 0 && dy == 0) {
      if (current == PlayerState.walkDown) { current = PlayerState.idleDown; }
      else if (current == PlayerState.walkUp) { current = PlayerState.idleUp; }
      else if (current == PlayerState.walkLeft) { current = PlayerState.idleLeft; }
      else if (current == PlayerState.walkRight) { current = PlayerState.idleRight; }
    } else {
      final dir = Vector2(dx, dy);
      if (dir.length > 0) dir.normalize();
      position.x = (position.x + dir.x * speed * dt).clamp(0.0, mapWidth);
      position.y = (position.y + dir.y * speed * dt).clamp(0.0, mapHeight);
      if (dx.abs() > dy.abs()) {
        current = dx > 0 ? PlayerState.walkRight : PlayerState.walkLeft;
      } else {
        current = dy > 0 ? PlayerState.walkDown : PlayerState.walkUp;
      }
    }

    super.update(dt);
  }
}
