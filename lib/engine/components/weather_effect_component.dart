import 'dart:math';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';

import 'package:farm_fintech/models/weather_event.dart';

// ── Pre-computed constant colors (avoid per-frame Color construction) ──

const Color _floodTint = Color(0x266EC6FF);
const Color _stormTint = Color(0x403D3D5C);
const Color _droughtTint = Color(0x44FF8800);
const Color _floodWaterColor = Color(0x8844AAFF);
const Color _floodHighlight = Color(0x408CD2FF);
const Color _lightningFlashColor = Color(0x40FFFFFF);
const Color _lightningBoltColor = Color(0xDDFFFF00);
const Color _shimmerColor = Color(0x10FFFFFF);
const Color _sunCoreColor = Color(0xA6FFEB3B);
const Color _sunGlowColor = Color(0x1FFFEB3B);

// Rain drop colors at different opacities (pre-baked to avoid Color.fromRGBO per frame)
const List<Color> _rainColors = [
  Color(0x406EC6FF), // ~0.25 opacity
  Color(0x556EC6FF), // ~0.33
  Color(0x666EC6FF), // ~0.40
  Color(0x806EC6FF), // ~0.50
  Color(0x996EC6FF), // ~0.60
  Color(0xB36EC6FF), // ~0.70
];

/// Pre-generated rain drop descriptor.
class _RainDrop {
  final double xFrac;
  final double yFrac;
  final double speed;
  final double length;
  final int colorIndex; // index into _rainColors

  const _RainDrop({
    required this.xFrac,
    required this.yFrac,
    required this.speed,
    required this.length,
    required this.colorIndex,
  });
}

/// Flame viewport overlay that renders weather visual effects.
///
/// Added to `camera.viewport` so it draws in screen-space on top of the
/// game world. Supports all four [DisasterType] states:
/// - **flood**: blue tint + rain + rising water
/// - **storm**: dark tint + heavy rain + lightning flashes
/// - **drought**: orange tint + heat shimmer + harsh sun
/// - **none**: nothing rendered
class WeatherEffectComponent extends Component
    with HasGameReference<FlameGame> {
  DisasterType _weather = DisasterType.none;
  double _elapsed = 0;
  double _lightningCooldown = 0;
  bool _lightningFlash = false;

  final List<_RainDrop> _drops = [];
  final Random _rng = Random();

  WeatherEffectComponent() {
    priority = -1; // Render behind joystick for clean UX
    _generateDrops(300);
  }

  // ── Public API ──────────────────────────────────────────────

  DisasterType get activeWeather => _weather;

  void setWeather(DisasterType type) {
    if (_weather == type) return;
    _weather = type;
    _elapsed = 0;
    _lightningCooldown = 2.0;
    _lightningFlash = false;
  }

  // ── Lifecycle ───────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (_weather == DisasterType.none) return;

    _elapsed += dt;

    // Storm lightning timing
    if (_weather == DisasterType.storm) {
      _lightningCooldown -= dt;
      if (_lightningCooldown <= 0) {
        _lightningFlash = true;
        _lightningCooldown = 2.5 + _rng.nextDouble() * 5.0;
        // Play thunder sound effect
        try {
          FlameAudio.play('thunder.mp3', volume: 0.7);
        } catch (e) {
          developer.log('Thunder audio error: $e', name: 'Weather');
        }
      } else if (_lightningFlash && _lightningCooldown < (2.5 + 5.0) - 0.12) {
        _lightningFlash = false;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_weather == DisasterType.none) return;

    final w = game.size.x;
    final h = game.size.y;
    if (w < 1 || h < 1 || !w.isFinite || !h.isFinite) return;

    // Truncate to whole pixels to avoid floating-point edge cases on web
    final sw = w.floorToDouble();
    final sh = h.floorToDouble();

    switch (_weather) {
      case DisasterType.flood:
        _tint(canvas, sw, sh, _floodTint);
        _rain(canvas, sw, sh, count: 200);
        _floodWater(canvas, sw, sh);
      case DisasterType.storm:
        _tint(canvas, sw, sh, _stormTint);
        _rain(canvas, sw, sh, count: 280, heavy: true);
        if (_lightningFlash) _lightning(canvas, sw, sh);
      case DisasterType.drought:
        _tint(canvas, sw, sh, _droughtTint);
        _heatShimmer(canvas, sw, sh);
        _harshSun(canvas, sw, sh);
      case DisasterType.none:
        break;
    }
  }

  // ── Private helpers ─────────────────────────────────────────

  void _generateDrops(int n) {
    _drops.clear();
    for (var i = 0; i < n; i++) {
      _drops.add(_RainDrop(
        xFrac: _rng.nextDouble(),
        yFrac: _rng.nextDouble(),
        speed: 0.3 + _rng.nextDouble() * 0.7,
        length: 6 + _rng.nextDouble() * 14,
        colorIndex: _rng.nextInt(_rainColors.length),
      ));
    }
  }

  // ─── Screen tint ───────────────────────────────────────────

  void _tint(Canvas canvas, double w, double h, Color color) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = color,
    );
  }

  // ─── Rain ──────────────────────────────────────────────────

  void _rain(Canvas canvas, double w, double h,
      {int count = 200, bool heavy = false}) {
    final paint = Paint()
      ..strokeWidth = heavy ? 1.8 : 1.2
      ..strokeCap = StrokeCap.round;

    final speed = heavy ? 2.5 : 1.5;
    final wind = heavy ? -3.0 : -1.5;
    final modH = h + 20; // avoid division by zero; drops wrap past screen

    for (var i = 0; i < count && i < _drops.length; i++) {
      final d = _drops[i];
      final x = d.xFrac * w;
      final y = (d.yFrac * h + _elapsed * h * speed * d.speed) % modH;

      paint.color = _rainColors[d.colorIndex];
      canvas.drawLine(
        Offset(x, y - d.length),
        Offset(x + wind, y),
        paint,
      );
    }
  }

  // ─── Flood water ───────────────────────────────────────────

  void _floodWater(Canvas canvas, double w, double h) {
    final waterH = h * 0.85; // Flood rises to cover 85% of the screen
    final bob = sin(_elapsed * 2) * 4;

    // Wavy water surface
    final path = Path()..moveTo(0, h - waterH + bob);
    for (var x = 0.0; x <= w; x += 16) {
      final wave = sin(x / 35 + _elapsed * 3) * 5;
      path.lineTo(x, h - waterH + wave + bob);
    }
    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    canvas.drawPath(path, Paint()..color = _floodWaterColor);

    // Surface highlight
    final hl = Path()..moveTo(0, h - waterH + bob + 4);
    for (var x = 0.0; x <= w; x += 16) {
      final wave = sin(x / 35 + _elapsed * 3) * 5;
      hl.lineTo(x, h - waterH + wave + bob + 4);
    }
    hl.lineTo(w, h - waterH + bob + 10);
    hl.lineTo(0, h - waterH + bob + 10);
    hl.close();
    canvas.drawPath(hl, Paint()..color = _floodHighlight);
  }

  // ─── Lightning ─────────────────────────────────────────────

  void _lightning(Canvas canvas, double w, double h) {
    // White flash
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = _lightningFlashColor,
    );

    // Bolt
    final bx = w * (0.3 + _rng.nextDouble() * 0.4);
    final bolt = Path()
      ..moveTo(bx, 0)
      ..lineTo(bx - 8, h * 0.15)
      ..lineTo(bx + 4, h * 0.15)
      ..lineTo(bx - 12, h * 0.35)
      ..lineTo(bx + 2, h * 0.25)
      ..lineTo(bx - 4, h * 0.25)
      ..lineTo(bx + 6, h * 0.08);

    canvas.drawPath(
      bolt,
      Paint()
        ..color = _lightningBoltColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  // ─── Heat shimmer ─────────────────────────────────────────

  void _heatShimmer(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = _shimmerColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 6; i++) {
      final y = h * 0.6 + i * 12;
      final p = Path()..moveTo(0, y);
      for (var x = 0.0; x < w; x += 15) {
        final wave = sin((x / 25) + _elapsed * 2.5 + i * 0.8) * 3;
        p.lineTo(x, y + wave);
      }
      canvas.drawPath(p, paint);
    }
  }

  // ─── Harsh sun (drought) ───────────────────────────────────

  void _harshSun(Canvas canvas, double w, double h) {
    final cx = w * 0.5;
    final cy = h * 0.08;
    canvas.drawCircle(Offset(cx, cy), 30, Paint()..color = _sunCoreColor);
    canvas.drawCircle(Offset(cx, cy), 55, Paint()..color = _sunGlowColor);
  }
}
