import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:farm_fintech/config/constants.dart';
import 'package:farm_fintech/config/theme.dart';

/// Pure code-based pixel art drawing helpers.
///
/// All sprites are drawn using [Canvas.drawRect] and [Canvas.drawPath]
/// — NO external image files (.png/.jpg).
class SpritePainter {
  const SpritePainter._();

  // ─── Crop Sprites ──────────────────────────────────────────

  /// Draw a crop at the given screen [position] (center-top of tile).
  static void drawCrop(
    Canvas canvas,
    Offset position,
    CropType type,
    int growthStage, // 0=seed, 1=sprout, 2=growing, 3=mature/harvestable
  ) {
    switch (growthStage) {
      case 0:
        _drawSeed(canvas, position);
      case 1:
        _drawSprout(canvas, position, type);
      case 2:
        _drawGrowing(canvas, position, type);
      case 3:
        _drawMature(canvas, position, type);
    }
  }

  static void _drawSeed(Canvas canvas, Offset pos) {
    final paint = Paint()..color = GameColors.seed;
    // Small dots representing planted seeds
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(pos.dx - 6 + i * 6, pos.dy + 20),
          width: 3,
          height: 3,
        ),
        paint,
      );
    }
  }

  static void _drawSprout(Canvas canvas, Offset pos, CropType type) {
    final Color color;
    switch (type) {
      case CropType.wheat:
        color = GameColors.wheatYoung;
      case CropType.rice:
        color = GameColors.riceYoung;
      case CropType.corn:
        color = GameColors.cornYoung;
    }
    final paint = Paint()..color = color;
    final stem = Paint()..color = color.withValues(alpha: 0.8);

    // Small stems poking up
    for (var i = 0; i < 3; i++) {
      final x = pos.dx - 6 + i * 6;
      // Stem
      canvas.drawRect(Rect.fromLTWH(x - 1, pos.dy + 12, 2, 8), stem);
      // Tiny leaf
      canvas.drawRect(Rect.fromLTWH(x - 2, pos.dy + 10, 4, 3), paint);
    }
  }

  static void _drawGrowing(Canvas canvas, Offset pos, CropType type) {
    final Color color;
    switch (type) {
      case CropType.wheat:
        color = GameColors.wheatYoung;
      case CropType.rice:
        color = GameColors.riceYoung;
      case CropType.corn:
        color = GameColors.cornYoung;
    }
    final paint = Paint()..color = color;
    final stem = Paint()..color = color.withValues(alpha: 0.7);

    // Taller stems with leaves
    for (var i = 0; i < 4; i++) {
      final x = pos.dx - 8 + i * 5;
      canvas.drawRect(Rect.fromLTWH(x - 1, pos.dy + 4, 2, 16), stem);
      canvas.drawRect(Rect.fromLTWH(x - 3, pos.dy + 4, 6, 4), paint);
      canvas.drawRect(Rect.fromLTWH(x - 2, pos.dy + 10, 4, 3), paint);
    }
  }

  static void _drawMature(Canvas canvas, Offset pos, CropType type) {
    final Color topColor;
    final Color stemColor;
    switch (type) {
      case CropType.wheat:
        topColor = GameColors.wheatMature;
        stemColor = GameColors.wheatYoung;
      case CropType.rice:
        topColor = GameColors.riceMature;
        stemColor = GameColors.riceYoung;
      case CropType.corn:
        topColor = GameColors.cornMature;
        stemColor = GameColors.cornYoung;
    }

    final topPaint = Paint()..color = topColor;
    final stemPaint = Paint()..color = stemColor;

    for (var i = 0; i < 5; i++) {
      final x = pos.dx - 10 + i * 5;
      // Tall stem
      canvas.drawRect(Rect.fromLTWH(x - 1, pos.dy, 2, 20), stemPaint);
      // Mature head / fruit
      canvas.drawRect(Rect.fromLTWH(x - 3, pos.dy - 4, 6, 6), topPaint);
      // Leaf detail
      canvas.drawRect(Rect.fromLTWH(x - 2, pos.dy + 8, 4, 3), stemPaint);
    }
  }

  // ─── Building Sprites ──────────────────────────────────────

  /// Draw a farmhouse at the given tile position.
  static void drawFarmhouse(Canvas canvas, Offset pos) {
    // Wall
    final wallPaint = Paint()..color = GameColors.buildingWall;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 14, pos.dy - 4, 28, 20), wallPaint);

    // Roof (triangle via path)
    final roofPaint = Paint()..color = GameColors.buildingRoof;
    final roofPath = Path()
      ..moveTo(pos.dx, pos.dy - 18)
      ..lineTo(pos.dx + 18, pos.dy - 4)
      ..lineTo(pos.dx - 18, pos.dy - 4)
      ..close();
    canvas.drawPath(roofPath, roofPaint);

    // Door
    final doorPaint = Paint()..color = GameColors.buildingRoof.withValues(alpha: 0.8);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 4, pos.dy + 4, 8, 12), doorPaint);

    // Windows
    final windowPaint = Paint()..color = GameColors.buildingWindow;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 12, pos.dy, 6, 6), windowPaint);
    canvas.drawRect(Rect.fromLTWH(pos.dx + 6, pos.dy, 6, 6), windowPaint);
  }

  /// Draw a bank building at the given tile position.
  static void drawBank(Canvas canvas, Offset pos) {
    // Wall — wider & taller
    final wallPaint = Paint()..color = GameColors.bankWall;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 18, pos.dy - 8, 36, 28), wallPaint);

    // Roof — flat with overhang
    final roofPaint = Paint()..color = GameColors.bankRoof;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 20, pos.dy - 12, 40, 6), roofPaint);

    // Columns
    final colPaint = Paint()..color = GameColors.bankRoof;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 14, pos.dy - 6, 3, 24), colPaint);
    canvas.drawRect(Rect.fromLTWH(pos.dx + 11, pos.dy - 6, 3, 24), colPaint);

    // Door
    canvas.drawRect(Rect.fromLTWH(pos.dx - 5, pos.dy + 6, 10, 14), roofPaint);

    // "$" symbol (simple pixel representation)
    final gold = Paint()..color = GameColors.uiGold;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 2, pos.dy - 4, 4, 2), gold);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 2, pos.dy - 2, 2, 2), gold);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 2, pos.dy, 4, 2), gold);
    canvas.drawRect(Rect.fromLTWH(pos.dx, pos.dy + 2, 2, 2), gold);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 2, pos.dy + 4, 4, 2), gold);
  }

  /// Draw a merchant shop at the given tile position.
  static void drawMerchantShop(Canvas canvas, Offset pos) {
    // Wall
    final wallPaint = Paint()..color = GameColors.merchantWall;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 16, pos.dy - 6, 32, 24), wallPaint);

    // Roof
    final roofPaint = Paint()..color = GameColors.merchantRoof;
    final roofPath = Path()
      ..moveTo(pos.dx, pos.dy - 20)
      ..lineTo(pos.dx + 20, pos.dy - 6)
      ..lineTo(pos.dx - 20, pos.dy - 6)
      ..close();
    canvas.drawPath(roofPath, roofPaint);

    // Awning
    final awningPaint = Paint()..color = GameColors.uiHighlight;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 18, pos.dy - 6, 36, 4), awningPaint);

    // Door
    canvas.drawRect(
      Rect.fromLTWH(pos.dx - 4, pos.dy + 6, 8, 12),
      Paint()..color = GameColors.merchantRoof,
    );

    // Display window
    final windowPaint = Paint()..color = GameColors.buildingWindow;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 14, pos.dy, 8, 8), windowPaint);
    canvas.drawRect(Rect.fromLTWH(pos.dx + 6, pos.dy, 8, 8), windowPaint);
  }

  /// Draw a decorative tree.
  static void drawTree(Canvas canvas, Offset pos) {
    // Trunk
    final trunkPaint = Paint()..color = GameColors.buildingRoof;
    canvas.drawRect(Rect.fromLTWH(pos.dx - 2, pos.dy + 4, 4, 12), trunkPaint);

    // Foliage — stacked layers
    final leafPaint = Paint()..color = GameColors.grassLight;
    final darkLeaf = Paint()..color = GameColors.grassDark;

    canvas.drawRect(Rect.fromLTWH(pos.dx - 8, pos.dy - 2, 16, 8), leafPaint);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 6, pos.dy - 8, 12, 8), leafPaint);
    canvas.drawRect(Rect.fromLTWH(pos.dx - 4, pos.dy - 12, 8, 6), darkLeaf);
  }

  // ─── Weather Effects ───────────────────────────────────────

  /// Draw rain particles across the canvas.
  static void drawRain(Canvas canvas, Size size, double animationPhase) {
    final paint = Paint()
      ..color = GameColors.rainDrop
      ..strokeWidth = 1.5;

    final rng = Random(42); // Deterministic seed for consistent pattern
    for (var i = 0; i < 120; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final y = (baseY + animationPhase * size.height) % size.height;

      canvas.drawLine(
        Offset(x, y),
        Offset(x - 2, y + 8),
        paint,
      );
    }
  }

  /// Draw a flood water overlay at the bottom portion.
  static void drawFloodOverlay(Canvas canvas, Size size, double severity) {
    final paint = Paint()..color = GameColors.floodWater;
    final height = size.height * 0.3 * severity;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - height, size.width, height),
      paint,
    );
  }
}
