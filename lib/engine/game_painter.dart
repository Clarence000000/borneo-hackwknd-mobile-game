import 'package:flutter/material.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/camera.dart';
import 'package:farm_fintech/engine/isometric_engine.dart';
import 'package:farm_fintech/engine/sprite_painter.dart';
import 'package:farm_fintech/models/tile.dart';
import 'package:farm_fintech/models/weather_event.dart';

/// Main [CustomPainter] that renders the entire isometric farm scene.
///
/// Draws in back-to-front order (painter's algorithm):
/// 1. Ground tiles (isometric diamonds)
/// 2. Crops / buildings on top of tiles
/// 3. Weather overlay effects
class GamePainter extends CustomPainter {
  final List<List<Tile>> grid;
  final GameCamera camera;
  final IsometricEngine engine;
  final (int, int)? selectedTile;
  final DisasterType? activeDisaster;
  final double animationPhase;

  GamePainter({
    required this.grid,
    required this.camera,
    required this.engine,
    this.selectedTile,
    this.activeDisaster,
    this.animationPhase = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // Apply camera transform
    canvas.transform(camera.transformMatrix.storage);

    // ── Draw grid tiles (back-to-front) ──────────────────────
    final rows = grid.length;
    final cols = rows > 0 ? grid[0].length : 0;

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final tile = grid[row][col];
        _drawTile(canvas, tile, col, row);
      }
    }

    canvas.restore();

    // ── Weather overlay (screen-space, on top of everything) ─
    if (activeDisaster != null && activeDisaster != DisasterType.none) {
      _drawWeatherOverlay(canvas, size);
    }
  }

  void _drawTile(Canvas canvas, Tile tile, int col, int row) {
    final points = engine.getTileDiamondPoints(col, row);
    final center = engine.gridToScreen(col, row);

    // ── Ground fill ──────────────────────────────────────────
    final groundColor = switch (tile.type) {
      TileType.grass => (col + row) % 2 == 0
          ? GameColors.grassLight
          : GameColors.grassDark,
      TileType.farmland => (col + row) % 2 == 0
          ? GameColors.dirt
          : GameColors.dirtDark,
      TileType.water => GameColors.water,
      TileType.building => GameColors.dirt,
    };

    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..close();

    canvas.drawPath(path, Paint()..color = groundColor);

    // Tile outline
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );

    // ── Selection highlight ──────────────────────────────────
    if (selectedTile != null &&
        selectedTile!.$1 == col &&
        selectedTile!.$2 == row) {
      canvas.drawPath(path, Paint()..color = GameColors.tileSelected);
    }

    // ── Crops ────────────────────────────────────────────────
    if (tile.hasCrop) {
      SpritePainter.drawCrop(canvas, center, tile.crop!, tile.growthStage);
    }

    // ── Buildings (drawn at special tile positions) ──────────
    if (tile.type == TileType.building) {
      // We'll identify building type by position convention for now
      // Bank at (0,0), Merchant at (0,1), Farmhouse at grid center
      if (col == 0 && row == 0) {
        SpritePainter.drawBank(canvas, center);
      } else if (col == 0 && row == 1) {
        SpritePainter.drawMerchantShop(canvas, center);
      } else {
        SpritePainter.drawFarmhouse(canvas, center);
      }
    }
  }

  void _drawWeatherOverlay(Canvas canvas, Size size) {
    switch (activeDisaster!) {
      case DisasterType.flood:
        SpritePainter.drawRain(canvas, size, animationPhase);
        SpritePainter.drawFloodOverlay(canvas, size, 0.6);
      case DisasterType.storm:
        SpritePainter.drawRain(canvas, size, animationPhase);
      case DisasterType.drought:
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()..color = GameColors.droughtTint,
        );
      case DisasterType.none:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.selectedTile != selectedTile ||
        oldDelegate.activeDisaster != activeDisaster ||
        oldDelegate.animationPhase != animationPhase ||
        true; // For now, always repaint. Optimize later with dirty flags.
  }
}
