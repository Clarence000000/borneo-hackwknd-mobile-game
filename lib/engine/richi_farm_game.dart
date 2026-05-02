import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/painting.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/providers/game_state.dart';

/// Main Flame game class — renders the Tiled map and handles camera controls.
///
/// Replaces the old [CustomPainter]-based engine (GamePainter, SkyPainter,
/// SpritePainter) with Flame's component system and built-in camera.
class RichiFarmGame extends FlameGame
    with PanDetector, ScaleDetector, HasKeyboardHandlerComponents {
  final GameState gameState;

  /// The loaded Tiled map component.
  late TiledComponent _mapComponent;

  // ── Scale gesture state ──────────────────────────────────────
  double _startZoom = 1.0;

  /// Camera zoom limits.
  static const double _minZoom = 0.5;
  static const double _maxZoom = 4.0;

  RichiFarmGame({required this.gameState});

  @override
  Color backgroundColor() => GameColors.uiBackground;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the Tiled map from assets/tiles/level1.tmx.
    // The tile size Vector2 controls the rendered pixel size per tile.
    // Using 16x16 to match the native tileset resolution.
    _mapComponent = await TiledComponent.load(
      'level1.tmx',
      Vector2.all(16),
    );

    world.add(_mapComponent);

    // Center the camera on the map.
    _centerCameraOnMap();
  }

  void _centerCameraOnMap() {
    final mapWidth = _mapComponent.tileMap.map.width * 16.0;
    final mapHeight = _mapComponent.tileMap.map.height * 16.0;

    // Position camera to look at the center of the map.
    camera.viewfinder.position = Vector2(mapWidth / 2, mapHeight / 2);

    // Fit the map into the viewport with some padding.
    if (size.x > 0 && size.y > 0) {
      final scaleX = size.x / mapWidth;
      final scaleY = size.y / mapHeight;
      final fitZoom = (scaleX < scaleY ? scaleX : scaleY) * 0.9;
      camera.viewfinder.zoom = fitZoom.clamp(_minZoom, _maxZoom);
    }
  }

  // ── Pan (drag to move camera) ─────────────────────────────────

  @override
  void onPanUpdate(DragUpdateInfo info) {
    final zoom = camera.viewfinder.zoom;
    camera.viewfinder.position -= info.delta.global / zoom;
  }

  // ── Scale (pinch to zoom) ─────────────────────────────────────

  @override
  void onScaleStart(ScaleStartInfo info) {
    _startZoom = camera.viewfinder.zoom;
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    final newZoom = _startZoom * info.scale.global.x;
    camera.viewfinder.zoom = newZoom.clamp(_minZoom, _maxZoom);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Re-center when screen rotates or resizes.
    if (isLoaded) {
      _centerCameraOnMap();
    }
  }
}
