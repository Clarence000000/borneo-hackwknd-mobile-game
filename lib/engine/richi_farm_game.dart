import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/painting.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/providers/game_state.dart';

/// Main Flame game class — renders the Tiled map fullscreen, no scrolling.
///
/// The map is scaled to cover the entire screen (no black borders).
/// Camera is locked — no pan or zoom gestures.
class RichiFarmGame extends FlameGame {
  final GameState gameState;

  /// The loaded Tiled map component.
  late TiledComponent _mapComponent;

  RichiFarmGame({required this.gameState});

  @override
  Color backgroundColor() => GameColors.uiBackground;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load the Tiled map from assets/tiles/level1.tmx.
    _mapComponent = await TiledComponent.load(
      'level1.tmx',
      Vector2.all(16),
    );

    world.add(_mapComponent);

    // Fill the screen with the map.
    _fitMapToScreen();
  }

  /// Scale and position the camera so the map covers the entire screen
  /// with no black borders. Uses "cover" strategy (like CSS background-size: cover)
  /// — the map may be slightly cropped on one axis but never shows edges.
  void _fitMapToScreen() {
    final mapWidth = _mapComponent.tileMap.map.width * 16.0;
    final mapHeight = _mapComponent.tileMap.map.height * 16.0;

    // Center the camera on the map.
    camera.viewfinder.position = Vector2(mapWidth / 2, mapHeight / 2);

    if (size.x > 0 && size.y > 0) {
      final scaleX = size.x / mapWidth;
      final scaleY = size.y / mapHeight;
      // Use the LARGER scale so the map fully covers the viewport.
      // Add a tiny 5% buffer to guarantee no edge pixels leak through.
      camera.viewfinder.zoom = (scaleX > scaleY ? scaleX : scaleY) * 1.05;
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _fitMapToScreen();
    }
  }
}
