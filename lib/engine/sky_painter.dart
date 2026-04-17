import 'dart:math';

import 'package:flutter/material.dart';

import 'package:farm_fintech/config/theme.dart';
import 'package:farm_fintech/models/weather_event.dart';

/// Draws a dynamic sky behind the isometric grid.
///
/// Reflects the current weather/disaster state:
/// - Normal: blue gradient with drifting clouds
/// - Rain/Storm: dark sky with rain streaks
/// - Drought: harsh orange/yellow tint
/// - Flood: dark grey with rain + rising water
class SkyPainter extends CustomPainter {
  final DisasterType weather;
  final double animationPhase;
  final int currentDay;

  SkyPainter({
    this.weather = DisasterType.none,
    this.animationPhase = 0,
    this.currentDay = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (weather) {
      case DisasterType.none:
        _drawClearSky(canvas, size);
      case DisasterType.flood:
        _drawRainSky(canvas, size);
        _drawRainDrops(canvas, size);
      case DisasterType.storm:
        _drawStormSky(canvas, size);
        _drawLightning(canvas, size);
        _drawRainDrops(canvas, size);
      case DisasterType.drought:
        _drawDroughtSky(canvas, size);
        _drawHeatShimmer(canvas, size);
    }

    // Always draw clouds (different styles per weather)
    if (weather == DisasterType.none) {
      _drawClouds(canvas, size, Colors.white.withValues(alpha: 0.7));
    } else if (weather == DisasterType.drought) {
      _drawClouds(canvas, size, Colors.white.withValues(alpha: 0.15));
    }

    // Draw ground horizon line
    _drawDistantGround(canvas, size);
    _drawGroundGradient(canvas, size);
  }

  // ─── Clear Day Sky ────────────────────────────────────────

  void _drawClearSky(Canvas canvas, Size size) {
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1A73E8), // Deep blue
        const Color(0xFF4FC3F7), // Light blue
        const Color(0xFFA8D8EA), // Pale horizon blue
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Sun
    final sunX = size.width * 0.8;
    final sunY = size.height * 0.12;
    canvas.drawCircle(
      Offset(sunX, sunY),
      28,
      Paint()..color = const Color(0xFFFFF176),
    );
    // Sun glow
    canvas.drawCircle(
      Offset(sunX, sunY),
      45,
      Paint()..color = const Color(0x33FFF176),
    );
  }

  // ─── Rain/Flood Sky ───────────────────────────────────────

  void _drawRainSky(Canvas canvas, Size size) {
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF2C3E50),
        const Color(0xFF4A6572),
        const Color(0xFF607D8B),
      ],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _drawRainDrops(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = GameColors.rainDrop.withValues(alpha: 0.5)
      ..strokeWidth = 1.2;

    final rng = Random(42);
    for (var i = 0; i < 200; i++) {
      final x = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final y = (baseY + animationPhase * size.height * 1.5) % size.height;
      final length = 6 + rng.nextDouble() * 10;

      canvas.drawLine(
        Offset(x, y),
        Offset(x - 1.5, y + length),
        paint,
      );
    }
  }

  // ─── Storm Sky ────────────────────────────────────────────

  void _drawStormSky(Canvas canvas, Size size) {
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF1A1A2E),
        const Color(0xFF2D2D44),
        GameColors.stormCloud,
      ],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  void _drawLightning(Canvas canvas, Size size) {
    // Flash effect at certain animation phases
    if (animationPhase > 0.85 && animationPhase < 0.90) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.white.withValues(alpha: 0.15),
      );

      // Lightning bolt
      final boltX = size.width * 0.6;
      final bolt = Path()
        ..moveTo(boltX, 0)
        ..lineTo(boltX - 10, size.height * 0.25)
        ..lineTo(boltX + 5, size.height * 0.25)
        ..lineTo(boltX - 15, size.height * 0.5)
        ..lineTo(boltX + 3, size.height * 0.35)
        ..lineTo(boltX - 5, size.height * 0.35)
        ..lineTo(boltX + 8, size.height * 0.12);

      canvas.drawPath(
        bolt,
        Paint()
          ..color = const Color(0xCCFFFF00)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  // ─── Drought Sky ──────────────────────────────────────────

  void _drawDroughtSky(Canvas canvas, Size size) {
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFFE65100), // Deep orange
        const Color(0xFFFF8F00), // Amber
        const Color(0xFFFFC107), // Yellow
      ],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = skyGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Harsh sun
    final sunX = size.width * 0.5;
    canvas.drawCircle(
      Offset(sunX, size.height * 0.1),
      40,
      Paint()..color = const Color(0xFFFFEB3B),
    );
    canvas.drawCircle(
      Offset(sunX, size.height * 0.1),
      65,
      Paint()..color = const Color(0x44FFEB3B),
    );
  }

  void _drawHeatShimmer(Canvas canvas, Size size) {
    // Wavy shimmer lines at the bottom
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    for (var i = 0; i < 8; i++) {
      final y = size.height * 0.7 + i * 8;
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x < size.width; x += 20) {
        final wave = sin((x / 30) + animationPhase * 2 * pi + i) * 3;
        path.lineTo(x, y + wave);
      }
      canvas.drawPath(path, paint);
    }
  }

  // ─── Clouds ───────────────────────────────────────────────

  void _drawClouds(Canvas canvas, Size size, Color color) {
    final paint = Paint()..color = color;
    final rng = Random(17);

    for (var i = 0; i < 5; i++) {
      final baseX = rng.nextDouble() * size.width;
      final driftX = (baseX + animationPhase * size.width * 0.3) % (size.width + 120) - 60;
      final yPos = 20 + rng.nextDouble() * size.height * 0.2;
      final w = 50 + rng.nextDouble() * 60;
      final h = 14 + rng.nextDouble() * 10;

      // Cloud = overlapping rounded rects
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(driftX, yPos, w, h), const Radius.circular(8)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(driftX + w * 0.2, yPos - h * 0.5, w * 0.6, h * 0.9), const Radius.circular(8)),
        paint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(driftX + w * 0.5, yPos - h * 0.2, w * 0.4, h * 0.7), const Radius.circular(6)),
        paint,
      );
    }
  }

  // ─── Ground horizon gradient ──────────────────────────────

  void _drawDistantGround(Canvas canvas, Size size) {
    final horizonY = size.height * 0.7;
    final paint = Paint()
      ..color = weather == DisasterType.drought
          ? const Color(0xFF8B6B4A) // Dusty brown
          : const Color(0xFF2E5A2E); // Darker green

    // Distant mountain-like silhouettes for depth
    final path = Path()
      ..moveTo(0, horizonY)
      ..lineTo(size.width * 0.2, horizonY - 15)
      ..lineTo(size.width * 0.4, horizonY - 5)
      ..lineTo(size.width * 0.7, horizonY - 20)
      ..lineTo(size.width, horizonY)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  void _drawGroundGradient(Canvas canvas, Size size) {
    final horizonY = size.height * 0.7;
    final groundGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withValues(alpha: 0.1),
        Colors.black.withValues(alpha: 0.4),
      ],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
      Paint()..shader = groundGradient.createShader(
        Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY),
      ),
    );

    // Explicit horizon line
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(size.width, horizonY),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant SkyPainter oldDelegate) {
    return oldDelegate.weather != weather ||
        oldDelegate.animationPhase != animationPhase;
  }
}
