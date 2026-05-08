import 'dart:developer' as developer;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/components/forest_npc_component.dart';
import 'package:farm_fintech/engine/components/player_component.dart';

/// Flame game for the Wild Forest map (forest.tmx).
///
/// Interaction model mirrors the main map:
/// - Proximity → sets [ForestNpcComponent.isNearPlayer] → fires [onNearNpcChanged]
/// - Screen tap → [handleTap] → world-space hit test → fires [onNpcTapped]
/// - Walking to exit zone → fires [onExit]
class ForestGame extends FlameGame
    with PanDetector, HasKeyboardHandlerComponents {
  // ── Callbacks set by ForestScreen ─────────────────────────
  void Function()? onExit;

  /// Fires when the nearest NPC changes — null means no NPC is nearby.
  void Function(String?)? onNearNpcChanged;

  /// Fires when the player taps an NPC sprite.
  void Function(String)? onNpcTapped;

  // ── Internal state ─────────────────────────────────────────
  late TiledComponent _mapComponent;
  late _ForestPlayerComponent _player;
  JoystickComponent? joystick;

  late double _mapWidth;
  late double _mapHeight;

  Rect _exitRect = Rect.zero;
  bool _hasExited = false;
  bool _hasLeftExitZone = false;

  final List<ForestNpcComponent> _npcComponents = [];
  String? _currentNearNpc;

  static const double _proximityRadius = 48.0;

  @override
  Color backgroundColor() => GameColors.uiBackground;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _mapComponent = await TiledComponent.load('forest.tmx', Vector2.all(16));
    _mapComponent.priority = 0;
    world.add(_mapComponent);

    final map = _mapComponent.tileMap.map;
    _mapWidth = map.width * map.tileWidth.toDouble();
    _mapHeight = map.height * map.tileHeight.toDouble();

    _loadExitRect(map);
    await _spawnNpcComponents(map);

    final spawnX = _exitRect != Rect.zero ? _exitRect.center.dx : _mapWidth / 2;
    final spawnY = _exitRect != Rect.zero ? _exitRect.center.dy : _mapHeight - 48;
    _player = _ForestPlayerComponent();
    _player.position = Vector2(spawnX, spawnY);
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

  // ── TMX parsing ────────────────────────────────────────────

  void _loadExitRect(dynamic map) {
    try {
      for (final layer in map.layers) {
        if ((layer.name as String?)?.toLowerCase() != 'exits') continue;
        for (final obj in (layer.objects as List)) {
          if ((obj.name as String?)?.toLowerCase() == 'exit') {
            _exitRect = Rect.fromLTWH(
              (obj.x as num).toDouble(),
              (obj.y as num).toDouble(),
              (obj.width as num?)?.toDouble() ?? 16.0,
              (obj.height as num?)?.toDouble() ?? 16.0,
            );
            developer.log('Forest exit: $_exitRect', name: 'ForestGame');
            return;
          }
        }
      }
    } catch (e) {
      developer.log('_loadExitRect error: $e', name: 'ForestGame');
    }
  }

  Future<void> _spawnNpcComponents(dynamic map) async {
    try {
      for (final layer in map.layers) {
        if ((layer.name as String?)?.toLowerCase() != 'npcs') continue;
        for (final obj in (layer.objects as List)) {
          final name = (obj.name as String?)?.toLowerCase();
          if (name == null || name.isEmpty) continue;
          final pos = Vector2(
            (obj.x as num).toDouble(),
            (obj.y as num).toDouble(),
          );
          final npc = ForestNpcComponent(npcName: name, npcPosition: pos);
          _npcComponents.add(npc);
          world.add(npc);
          developer.log('Forest NPC "$name" at $pos', name: 'ForestGame');
        }
      }
    } catch (e) {
      developer.log('_spawnNpcComponents error: $e', name: 'ForestGame');
    }
  }

  // ── Game loop ──────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    _checkExit();
    _checkNpcProximity();
    camera.viewfinder.position = _player.position;
    _clampCamera();
  }

  void _checkExit() {
    if (_hasExited || _exitRect == Rect.zero) return;
    final inExit = _exitRect.contains(
      Offset(_player.position.x, _player.position.y),
    );
    if (!_hasLeftExitZone) {
      if (!inExit) _hasLeftExitZone = true;
    } else if (inExit) {
      _hasExited = true;
      onExit?.call();
    }
  }

  void _checkNpcProximity() {
    String? nearest;
    double nearestDist = double.infinity;

    for (final npc in _npcComponents) {
      final center = npc.position + Vector2(16, 16);
      final dist = _player.position.distanceTo(center);
      npc.isNearPlayer = dist < _proximityRadius;
      if (npc.isNearPlayer && dist < nearestDist) {
        nearestDist = dist;
        nearest = npc.npcName;
      }
    }

    if (nearest != _currentNearNpc) {
      _currentNearNpc = nearest;
      onNearNpcChanged?.call(nearest);
    }
  }

  // ── Tap handling (called from ForestScreen GestureDetector) ──

  void handleTap(Offset screenPos) {
    if (size.x <= 0 || size.y <= 0) return;
    final zoom = camera.viewfinder.zoom;
    if (zoom <= 0) return;

    final worldX = camera.viewfinder.position.x +
        (screenPos.dx - size.x / 2) / zoom;
    final worldY = camera.viewfinder.position.y +
        (screenPos.dy - size.y / 2) / zoom;

    for (final npc in _npcComponents) {
      if (npc.containsWorldPoint(worldX, worldY)) {
        developer.log('Tap → NPC "${npc.npcName}"', name: 'ForestGame');
        onNpcTapped?.call(npc.npcName);
        return;
      }
    }
  }

  // ── Camera ─────────────────────────────────────────────────

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

// ── Player ─────────────────────────────────────────────────────

class _ForestPlayerComponent
    extends SpriteAnimationGroupComponent<PlayerState>
    with HasGameReference<ForestGame>, KeyboardHandler {
  static const double speed = 100.0;

  double mapWidth = 0;
  double mapHeight = 0;

  int _horizontalDirection = 0;
  int _verticalDirection = 0;

  _ForestPlayerComponent() : super(size: Vector2(48, 48));

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
        keysPressed.contains(LogicalKeyboardKey.arrowLeft)) _horizontalDirection -= 1;
    if (keysPressed.contains(LogicalKeyboardKey.keyD) ||
        keysPressed.contains(LogicalKeyboardKey.arrowRight)) _horizontalDirection += 1;
    if (keysPressed.contains(LogicalKeyboardKey.keyW) ||
        keysPressed.contains(LogicalKeyboardKey.arrowUp)) _verticalDirection -= 1;
    if (keysPressed.contains(LogicalKeyboardKey.keyS) ||
        keysPressed.contains(LogicalKeyboardKey.arrowDown)) _verticalDirection += 1;

    // F key → interact with nearest NPC
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyF &&
        game._currentNearNpc != null) {
      game.onNpcTapped?.call(game._currentNearNpc!);
    }

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
      if (current == PlayerState.walkDown)       current = PlayerState.idleDown;
      else if (current == PlayerState.walkUp)    current = PlayerState.idleUp;
      else if (current == PlayerState.walkLeft)  current = PlayerState.idleLeft;
      else if (current == PlayerState.walkRight) current = PlayerState.idleRight;
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
