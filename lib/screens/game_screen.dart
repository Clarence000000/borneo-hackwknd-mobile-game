import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/game_painter.dart';
import 'package:farm_fintech/engine/sky_painter.dart';
import 'package:farm_fintech/models/tile.dart';
import 'package:farm_fintech/providers/game_state.dart';
import 'package:farm_fintech/widgets/hud_overlay.dart';

/// Main game screen — landscape isometric farm view.
///
/// Layered rendering (per 2d-games skill):
///   Sky → Isometric Grid → HUD → Tile Action Bar
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Offset _lastFocalPoint = Offset.zero;
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Slower for smoother sky
    )..repeat();

    // Center camera after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<GameState>();
      state.centerCamera(MediaQuery.of(context).size);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.uiBackground,
      body: Consumer<GameState>(
        builder: (context, state, _) {
          return Stack(
            children: [
              // ── Layer 0: Dynamic Sky Background ──────────
              AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: SkyPainter(
                      weather: state.activeDisaster,
                      animationPhase: _animController.value,
                      currentDay: state.currentDay,
                    ),
                    size: Size.infinite,
                  );
                },
              ),

              // ── Layer 1: Isometric Farm Grid ────────────
              GestureDetector(
                onScaleStart: (details) {
                  _lastFocalPoint = details.focalPoint;
                  _baseScale = state.camera.scale;
                },
                onScaleUpdate: (details) {
                  // Pan: translate by focal point delta
                  final delta = details.focalPoint - _lastFocalPoint;
                  _lastFocalPoint = details.focalPoint;
                  state.panCamera(delta);

                  // Zoom: only when pinching (2+ fingers)
                  if (details.scale != 1.0) {
                    final newScale = _baseScale * details.scale;
                    state.camera.zoom(newScale, details.focalPoint);
                  }
                },
                onTapUp: (details) {
                  state.handleTap(details.localPosition);
                },
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: GamePainter(
                        grid: state.grid,
                        camera: state.camera,
                        engine: state.engine,
                        selectedTile: state.selectedTile,
                        activeDisaster: state.activeDisaster,
                        animationPhase: _animController.value,
                      ),
                      size: Size.infinite,
                    );
                  },
                ),
              ),

              // ── Layer 2: HUD Overlay ────────────────────
              const HudOverlay(),

              // ── Layer 3: Tile Action Bar (bottom sheet) ──
              if (state.selectedTile != null) _buildTileActionBar(state),
            ],
          );
        },
      ),
    );
  }

  /// Bottom action bar for the selected tile.
  /// Redesigned for landscape — compact horizontal layout.
  Widget _buildTileActionBar(GameState state) {
    final (col, row) = state.selectedTile!;
    final tile = state.grid[row][col];

    return Positioned(
      bottom: 8,
      left: MediaQuery.of(context).size.width * 0.15,
      right: MediaQuery.of(context).size.width * 0.15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: GameColors.uiPanel.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
          border: Border.all(
            color: GameColors.uiAccent.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            // Tile info
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tile.type.name.toUpperCase()} ($col, $row)',
                  style: const TextStyle(
                    color: GameColors.uiText,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (tile.hasCrop && !tile.isHarvestable)
                  Text(
                    '${tile.crop!.name.toUpperCase()} — Stage ${tile.growthStage}/3',
                    style: const TextStyle(
                        color: GameColors.uiGold, fontSize: 12),
                  ),
                if (tile.type == TileType.grass)
                  const Text(
                    'Buy land at Bank to farm here',
                    style:
                        TextStyle(color: GameColors.uiTextDim, fontSize: 11),
                  ),
              ],
            ),
            const Spacer(),
            // Action buttons (horizontal)
            if (tile.isFarmland && !tile.hasCrop) ..._buildPlantChips(state),
            if (tile.isHarvestable) _buildHarvestChip(state),
            // Close button
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, color: GameColors.uiTextDim, size: 18),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () {
                state.selectedTile = null;
                state.refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPlantChips(GameState state) {
    return CropType.values.map((crop) {
      final config = kCropConfig[crop]!;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ActionChip(
          avatar: const Icon(Icons.grass, size: 14, color: GameColors.uiGreen),
          label: Text('${config['name']} \$${(config['seedCost'] as double).toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 11)),
          backgroundColor: GameColors.uiAccent,
          labelStyle: const TextStyle(color: GameColors.uiText),
          side: BorderSide.none,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: () {
            final success = state.plantCrop(crop);
            if (!success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Not enough money!')),
              );
            }
          },
        ),
      );
    }).toList();
  }

  Widget _buildHarvestChip(GameState state) {
    return ActionChip(
      avatar: const Icon(Icons.agriculture, size: 14, color: GameColors.uiBackground),
      label: const Text('HARVEST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
      backgroundColor: GameColors.uiGold,
      labelStyle: const TextStyle(color: GameColors.uiBackground),
      side: BorderSide.none,
      onPressed: () {
        final revenue = state.harvestCrop();
        if (revenue != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Harvested! +\$${revenue.toStringAsFixed(0)}')),
          );
        }
      },
    );
  }
}
