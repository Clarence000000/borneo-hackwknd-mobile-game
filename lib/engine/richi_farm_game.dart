import 'dart:developer' as developer;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/painting.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/components/building_component.dart';
import 'package:farm_fintech/engine/components/crop_component.dart';
import 'package:farm_fintech/engine/components/player_component.dart';
import 'package:farm_fintech/engine/components/interaction_keyboard_handler.dart';
import 'package:farm_fintech/engine/crop_image_registry.dart';
import 'package:farm_fintech/providers/game_state.dart';

/// Main Flame game class — renders the Tiled map with crops and player.
///
/// The map fills the screen (cover scaling). Camera follows the player or
/// can be panned manually. Crops are [SpriteComponent]s placed on top of
/// the tile map at grid positions.
class RichiFarmGame extends FlameGame with PanDetector, HasKeyboardHandlerComponents {
  final GameState gameState;

  /// The loaded Tiled map component.
  late TiledComponent _mapComponent;
  TiledComponent get mapComponent => _mapComponent;

  /// Map pixel dimensions (calculated from TMX metadata).
  late double _mapWidth;
  late double _mapHeight;

  /// Active crop components, keyed by (col, row).
  final Map<(int, int), CropComponent> _cropComponents = {};

  /// Player character.
  late PlayerComponent playerComponent;

  /// Joystick.
  JoystickComponent? joystick;

  /// Buildings on the map.
  final List<BuildingComponent> _buildings = [];
  List<BuildingComponent> get buildings => _buildings;

  /// Callback when a building is tapped — set by GameScreen for navigation.
  void Function(BuildingType type)? onBuildingTapped;

  RichiFarmGame({required this.gameState});

  @override
  Color backgroundColor() => GameColors.uiBackground;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Wire up game reference so GameState can call back.
    gameState.game = this;

    // Load the Tiled map from assets/tiles/level1.tmx.
    _mapComponent = await TiledComponent.load('level1.tmx', Vector2.all(16));

    final map = _mapComponent.tileMap.map;
    _mapWidth = map.width * map.tileWidth.toDouble();
    _mapHeight = map.height * map.tileHeight.toDouble();

    world.add(_mapComponent);

    // Mark farmland tiles from the TMX Tilled_Dirt layer.
    try {
      gameState.markFarmableFromTiled(_mapComponent.tileMap.map);
    } catch (e) {
      developer.log('markFarmableFromTiled error: $e', name: 'RichiFarmGame');
    }

    // Pre-cache crop sprites.
    developer.log('Loading crop images...', name: 'RichiFarmGame');
    await CropImageRegistry.loadAll();
    developer.log('Crop images loaded', name: 'RichiFarmGame');

    // ── Player character ──────────────────────────────────────
    playerComponent = PlayerComponent();
    playerComponent.position = Vector2((_mapWidth / 2) + 120, _mapHeight / 2);
    playerComponent.mapWidth = _mapWidth;
    playerComponent.mapHeight = _mapHeight;
    world.add(playerComponent);

    // Keyboard handler for crop interactions
    add(InteractionKeyboardHandler());

    // Joystick (always shown — on mobile it's the primary control,
    // on desktop/web it's supplementary to WASD/arrow keys).
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

    // ── Buildings ──────────────────────────────────────────
    // Bank: ~3×4 tiles, placed near top-left
    final bank = BuildingComponent(
      buildingType: BuildingType.bank,
      gridCol: 2,
      gridRow: 2,
      buildingSize: Vector2(48, 64), // 3×4 tiles
    );
    _buildings.add(bank);
    world.add(bank);

    // Merchant: ~3×3 tiles, placed a bit further
    final merchant = BuildingComponent(
      buildingType: BuildingType.merchant,
      gridCol: 8,
      gridRow: 2,
      buildingSize: Vector2(48, 48), // 3×3 tiles
    );
    _buildings.add(merchant);
    world.add(merchant);

    // Set up camera.
    _setupCamera();
  }

  // ── Camera ──────────────────────────────────────────────────

  void _setupCamera() {
    if (size.x <= 0 || size.y <= 0) return;

    // "Cover" zoom — use the LARGER axis scale so no black borders show.
    final scaleX = size.x / _mapWidth;
    final scaleY = size.y / _mapHeight;
    camera.viewfinder.zoom = scaleX > scaleY ? scaleX : scaleY;

    // Center on the map initially.
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

      // Guard against floating point precision errors when viewport >= map size
      if (minX >= maxX) {
        pos.x = _mapWidth / 2; // Center horizontally
      } else {
        pos.x = pos.x.clamp(minX, maxX);
      }

      if (minY >= maxY) {
        pos.y = _mapHeight / 2; // Center vertically
      } else {
        pos.y = pos.y.clamp(minY, maxY);
      }

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
    if (isLoaded) {
      _setupCamera();
    }
  }

  // ── Tap handling (called from GameScreen GestureDetector) ───

  /// Convert a screen tap position to grid coordinates and select the tile.
  void handleTap(Offset screenPos) {
    if (size.x <= 0 || size.y <= 0) return;

    final zoom = camera.viewfinder.zoom;
    if (zoom <= 0) return;

    final screenCenterX = size.x / 2;
    final screenCenterY = size.y / 2;

    final camX = camera.viewfinder.position.x;
    final camY = camera.viewfinder.position.y;

    final worldX = camX + (screenPos.dx - screenCenterX) / zoom;
    final worldY = camY + (screenPos.dy - screenCenterY) / zoom;

    // Check if tap hit a building first.
    for (final building in _buildings) {
      if (building.containsWorldPoint(worldX, worldY)) {
        developer.log(
          'Tap → building ${building.buildingType.name}',
          name: 'RichiFarmGame',
        );
        onBuildingTapped?.call(building.buildingType);
        return; // Don't select a tile if we tapped a building.
      }
    }

    final map = _mapComponent.tileMap.map;
    final mapCol = (worldX / 16).floor().clamp(0, map.width - 1);
    final mapRow = (worldY / 16).floor().clamp(0, map.height - 1);

    developer.log(
      'Tap → world(${worldX.toStringAsFixed(1)}, ${worldY.toStringAsFixed(1)}) → tile($mapCol, $mapRow)',
      name: 'RichiFarmGame',
    );

    gameState.selectTile((mapCol, mapRow));
  }

  // ── Crop component management ──────────────────────────────

  /// Add a crop sprite at the given grid position.
  void addCropComponent(int col, int row, CropType cropType, int stage) {
    // Remove existing crop at this position if any.
    removeCropComponent(col, row);

    final crop = CropComponent(
      cropType: cropType,
      gridCol: col,
      gridRow: row,
      initialStage: stage,
    );
    _cropComponents[(col, row)] = crop;
    world.add(crop);

    developer.log(
      'Added ${cropType.name} crop at ($col, $row) stage $stage',
      name: 'RichiFarmGame',
    );
  }

  /// Remove the crop sprite at the given grid position.
  void removeCropComponent(int col, int row) {
    final existing = _cropComponents.remove((col, row));
    if (existing != null) {
      existing.removeFromParent();
      developer.log(
        'Removed crop at ($col, $row)',
        name: 'RichiFarmGame',
      );
    }
  }

  /// Update the growth stage of the crop at the given position.
  void updateCropStage(int col, int row, int newStage) {
    final crop = _cropComponents[(col, row)];
    if (crop != null) {
      crop.updateStage(newStage);
    }
  }

  /// Bulk-sync all crop components from the GameState grid.
  ///
  /// Called after day advance or loading saved state to ensure
  /// the visual sprites match the logical tile state.
  void syncCropsFromGameState() {
    final grid = gameState.grid;

    // Track which positions have active crops in GameState.
    final activeCropPositions = <(int, int)>{};

    for (int row = 0; row < grid.length; row++) {
      for (int col = 0; col < grid[row].length; col++) {
        final tile = grid[row][col];
        if (tile.hasCrop) {
          activeCropPositions.add((col, row));
          final existing = _cropComponents[(col, row)];
          if (existing != null) {
            // Crop exists — update stage if needed.
            if (existing.currentStage != tile.growthStage) {
              existing.updateStage(tile.growthStage);
            }
          } else {
            // Crop is new — add component.
            addCropComponent(col, row, tile.crop!, tile.growthStage);
          }
        }
      }
    }

    // Remove crops that no longer exist in GameState (harvested/destroyed).
    final toRemove = _cropComponents.keys
        .where((pos) => !activeCropPositions.contains(pos))
        .toList();
    for (final pos in toRemove) {
      removeCropComponent(pos.$1, pos.$2);
    }
  }

  // ── Debug / Helper ──────────────────────────────────────────

  /// Respawns the player to a safe space slightly right of the center of the map to prevent getting stuck.
  void respawnPlayer() {
    playerComponent.position = Vector2((_mapWidth / 2) + 120, _mapHeight / 2);
    _setupCamera(); // Re-center the camera
    developer.log('Respawned player near map center.', name: 'RichiFarmGame');
  }
}
