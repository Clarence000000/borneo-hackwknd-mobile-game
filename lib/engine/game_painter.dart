import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/engine/camera.dart';
import 'package:farm_fintech/engine/isometric_engine.dart';
import 'package:farm_fintech/engine/sprite_painter.dart';
import 'package:farm_fintech/models/tile.dart';

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
  final double animationPhase;

  GamePainter({
    required this.grid,
    required this.camera,
    required this.engine,
    this.selectedTile,
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


  }

  void _drawTile(Canvas canvas, Tile tile, int col, int row) {
    final points = engine.getTileDiamondPoints(col, row);
    final center = engine.gridToScreen(col, row);

    // ── Ground fill ──────────────────────────────────────────
    final groundColor = switch (tile.type) {
      TileType.grass =>
        (col + row) % 2 == 0 ? GameColors.grassLight : GameColors.grassDark,
      TileType.farmland =>
        (col + row) % 2 == 0 ? GameColors.dirt : GameColors.dirtDark,
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
      _drawCropStatusBadge(canvas, tile, center);
      if (tile.isHarvestable) {
        _drawHarvestBubble(canvas, center);
      }
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

  void _drawCropStatusBadge(Canvas canvas, Tile tile, Offset center) {
    final isReady = tile.isHarvestable;
    final remainingDays = (3 - tile.growthStage).clamp(0, 3);
    final label = isReady
        ? 'READY'
        : remainingDays == 1
        ? 'Tomorrow'
        : '$remainingDays DAYS';
    final badgeColor = isReady ? GameColors.uiGold : GameColors.uiAccent;
    final textColor = isReady ? GameColors.uiBackground : GameColors.uiText;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeWidth = textPainter.width + 10;
    final badgeHeight = textPainter.height + 4;
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - 14),
        width: badgeWidth,
        height: badgeHeight,
      ),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      badgeRect,
      Paint()..color = badgeColor.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
    );

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - 14 - textPainter.height / 2,
      ),
    );
  }



  void _drawHarvestBubble(Canvas canvas, Offset center) {
    final bob = math.sin(animationPhase * 4) * 2.5;
    final bubbleCenter = Offset(center.dx + 14, center.dy - 30 + bob);

    final fill = Paint()..color = GameColors.uiGold.withValues(alpha: 0.95);
    final stroke = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawCircle(bubbleCenter, 9, fill);
    canvas.drawCircle(bubbleCenter, 9, stroke);

    final iconPainter = TextPainter(
      text: const TextSpan(text: '🧺', style: TextStyle(fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      Offset(
        bubbleCenter.dx - iconPainter.width / 2,
        bubbleCenter.dy - iconPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) {
    return oldDelegate.selectedTile != selectedTile ||
        oldDelegate.animationPhase != animationPhase ||
        true; // For now, always repaint. Optimize later with dirty flags.
  }
}
