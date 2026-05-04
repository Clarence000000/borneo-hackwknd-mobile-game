import 'dart:developer' as developer;

import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/painting.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/engine/crop_image_registry.dart';

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

    gameState.game = this;

    // Load the Tiled map from assets/tiles/level1.tmx.
    _mapComponent = await TiledComponent.load('level1.tmx', Vector2.all(16));

    world.add(_mapComponent);
    try {
      gameState.markFarmableFromTiled(_mapComponent.tileMap.map);
    } catch (_) {}

    // Load crop images (if present) and then fit map to screen.
    developer.log('Calling CropImageRegistry.loadAll()', name: 'RichiFarmGame');
    await CropImageRegistry.loadAll();
    developer.log(
      'CropImageRegistry.loadAll() completed',
      name: 'RichiFarmGame',
    );

    // Fill the screen with the map.
    _fitMapToScreen();
  }

  /// Returns true if the loaded map contains a layer with the given name
  /// (case-insensitive). Used by `GameState` to detect which layer to update
  /// at runtime.
  bool hasLayer(String layerName) {
    try {
      final map = _mapComponent.tileMap.map;
      return map.layers.any((l) => (l.name as String?)?.toLowerCase() == layerName.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  /// Scale and position the camera so the entire 60×40 map fits on screen.
  /// Uses "contain" strategy — all content visible, may have black bars.
  void _fitMapToScreen() {
    final mapWidth = _mapComponent.tileMap.map.width * 16.0; // 60 * 16 = 960
    final mapHeight = _mapComponent.tileMap.map.height * 16.0; // 40 * 16 = 640

    // Center the camera on the map.
    camera.viewfinder.position = Vector2(mapWidth / 2, mapHeight / 2);

    if (size.x > 0 && size.y > 0) {
      final scaleX = size.x / mapWidth;
      final scaleY = size.y / mapHeight;
      // Use the SMALLER scale so the entire map fits on screen.
      // This ensures all 60×40 tiles are visible.
      final scale = scaleX < scaleY ? scaleX : scaleY;
      camera.viewfinder.zoom = scale * 0.95; // 5% buffer for padding

      developer.log(
        'Map fit: ${mapWidth.toInt()}×${mapHeight.toInt()}px, '
        'screen: ${size.x.toInt()}×${size.y.toInt()}px, '
        'zoom: ${camera.viewfinder.zoom.toStringAsFixed(2)}',
        name: 'RichiFarmGame',
      );
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      _fitMapToScreen();
    }
  }

  /// Select the logical farm tile corresponding to a screen tap.
  void handleTap(Offset screenPos) {
    if (size.x <= 0 || size.y <= 0) return;

    final zoom = camera.viewfinder.zoom;
    if (zoom <= 0) return;

    developer.log('═══ FULL TAP DEBUG ═══', name: 'RichiFarmGame');
    developer.log(
      'Screen size: ${size.x.toStringAsFixed(0)} x ${size.y.toStringAsFixed(0)}',
      name: 'RichiFarmGame',
    );
    developer.log(
      'Tap screen pos: ${screenPos.dx.toStringAsFixed(1)}, ${screenPos.dy.toStringAsFixed(1)}',
      name: 'RichiFarmGame',
    );

    final camX = camera.viewfinder.position.x;
    final camY = camera.viewfinder.position.y;
    developer.log(
      'Camera pos: ${camX.toStringAsFixed(1)}, ${camY.toStringAsFixed(1)}',
      name: 'RichiFarmGame',
    );
    developer.log(
      'Camera zoom: ${zoom.toStringAsFixed(3)}',
      name: 'RichiFarmGame',
    );

    // Screen center
    final screenCenterX = size.x / 2;
    final screenCenterY = size.y / 2;
    developer.log(
      'Screen center: ${screenCenterX.toStringAsFixed(0)}, ${screenCenterY.toStringAsFixed(0)}',
      name: 'RichiFarmGame',
    );

    // Offset from screen center
    final offsetX = screenPos.dx - screenCenterX;
    final offsetY = screenPos.dy - screenCenterY;
    developer.log(
      'Offset from center: ${offsetX.toStringAsFixed(1)}, ${offsetY.toStringAsFixed(1)}',
      name: 'RichiFarmGame',
    );

    final worldX = camX + offsetX / zoom;
    final worldY = camY + offsetY / zoom;
    developer.log(
      'World pos: ${worldX.toStringAsFixed(1)}, ${worldY.toStringAsFixed(1)}',
      name: 'RichiFarmGame',
    );

    final map = _mapComponent.tileMap.map;
    final mapCol = (worldX ~/ 16).clamp(0, map.width - 1).toInt();
    final mapRow = (worldY ~/ 16).clamp(0, map.height - 1).toInt();

    developer.log(
      'Map size: ${map.width} x ${map.height}',
      name: 'RichiFarmGame',
    );
    developer.log(
      'Raw tile: col=${(worldX / 16).toStringAsFixed(2)}, row=${(worldY / 16).toStringAsFixed(2)}',
      name: 'RichiFarmGame',
    );
    developer.log('Final tile: $mapCol, $mapRow', name: 'RichiFarmGame');

    // Debug: Check what tile is at this location in grid
    final tile = gameState.grid[mapRow][mapCol];
    developer.log('Grid tile type: ${tile.type.name}', name: 'RichiFarmGame');

    // Debug: Print all available layers and their GIDs at this tile
    developer.log(
      'Available layers: ${map.layers.map((l) => l.name).join(", ")}',
      name: 'RichiFarmGame',
    );

    for (final layer in map.layers) {
      if (layer is! TileLayer) continue;
      final gid = getTileGidAt(layer.name, mapCol, mapRow);
      developer.log(
        'Layer "${layer.name}" at ($mapCol, $mapRow): GID = $gid',
        name: 'RichiFarmGame',
      );
    }
    developer.log('═════════════════════', name: 'RichiFarmGame');

    gameState.selectTile((mapCol, mapRow));
  }

  /// Update a tile's GID in the specified layer at (col, row).
  ///
  /// This is used for runtime changes, such as switching crop growth stages.
  /// Example:
  ///   setTileGidAt('crops', 10, 5, 42); // Change tile at (10,5) to GID 42
  ///
  /// After calling this, the TiledComponent will render the new tile image
  /// in the next frame.
  void setTileGidAt(String layerName, int col, int row, int newGid) {
    try {
      final map = _mapComponent.tileMap.map;
      final layer =
          map.layers.firstWhere(
                (l) => l.name == layerName,
                orElse: () => throw Exception('Layer "$layerName" not found'),
              )
              as TileLayer;

      final data = layer.data;
      if (data == null) {
        developer.log(
          'Layer "$layerName" has no tile data',
          name: 'RichiFarmGame',
        );
        return;
      }

      final mapWidth = map.width;
      final idx = row * mapWidth + col;

      if (idx < 0 || idx >= data.length) {
        developer.log(
          'Index $idx out of bounds for layer "$layerName"',
          name: 'RichiFarmGame',
        );
        return;
      }

      developer.log(
        'setTileGidAt($layerName, $col, $row): ${data[idx]} -> $newGid',
        name: 'RichiFarmGame',
      );
      data[idx] = newGid;
    } catch (e) {
      developer.log('Error in setTileGidAt: $e', name: 'RichiFarmGame');
    }
  }

  /// Get the current GID of a tile in the specified layer.
  int? getTileGidAt(String layerName, int col, int row) {
    try {
      final map = _mapComponent.tileMap.map;
      final layer =
          map.layers.firstWhere(
                (l) => l.name == layerName,
                orElse: () => throw Exception('Layer "$layerName" not found'),
              )
              as TileLayer;

      final data = layer.data;
      if (data == null) {
        return null;
      }

      final mapWidth = map.width;
      final idx = row * mapWidth + col;

      if (idx < 0 || idx >= data.length) {
        return null;
      }

      return data[idx];
    } catch (e) {
      developer.log('Error in getTileGidAt: $e', name: 'RichiFarmGame');
      return null;
    }
  }
}
