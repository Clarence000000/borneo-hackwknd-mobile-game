import 'dart:math';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';

import 'package:farm_fintech/models/weather_event.dart';

// ── Pre-computed constant colors (avoid per-frame Color construction) ──

const Color _stormTint = Color(0x403D3D5C);
const Color _droughtTint = Color(0x44FF8800);
const Color _lightningFlashColor = Color(0x40FFFFFF);
const Color _lightningBoltColor = Color(0xDDFFFF00);
const Color _shimmerColor = Color(0x10FFFFFF);
const Color _sunCoreColor = Color(0xA6FFEB3B);
const Color _sunGlowColor = Color(0x1FFFEB3B);

// ── Flood ambient colors ──
const Color _floodAmbientBase = Color(0xFF003344); // Deep teal / navy
const Color _rippleColor = Color(0xFF66CCFF);       // Light blue for ripples

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

/// A single ripple particle — spawned at a random position, expands and fades.
class _Ripple {
  double x;
  double y;
  double radius;
  double maxRadius;
  double alpha;
  double speed; // expansion speed in px/s

  _Ripple({
    required this.x,
    required this.y,
    required this.maxRadius,
    required this.speed,
  })  : radius = 0,
        alpha = 0.6;

  /// Returns true when the ripple has fully faded out and should be removed.
  bool update(double dt) {
    radius += speed * dt;
    // Fade linearly as the ripple expands
    alpha = (1.0 - radius / maxRadius).clamp(0.0, 1.0) * 0.5;
    return radius >= maxRadius;
  }
}

/// Flame viewport overlay that renders weather visual effects.
///
/// Added to `camera.viewport` so it draws in screen-space on top of the
/// game world. Supports all four [DisasterType] states:
/// - **flood**: ambient deep-teal overlay + breathing alpha + rain + ripple particles
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
  final List<_Ripple> _ripples = [];
  final Random _rng = Random();
  double _rippleSpawnTimer = 0;

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
    _ripples.clear();
    _rippleSpawnTimer = 0;
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

    // Flood ripple particle system
    if (_weather == DisasterType.flood) {
      _rippleSpawnTimer -= dt;
      if (_rippleSpawnTimer <= 0) {
        final w = game.size.x;
        final h = game.size.y;
        if (w > 1 && h > 1) {
          _ripples.add(_Ripple(
            x: _rng.nextDouble() * w,
            y: _rng.nextDouble() * h,
            maxRadius: 12 + _rng.nextDouble() * 20,
            speed: 15 + _rng.nextDouble() * 25,
          ));
        }
        // Spawn a new ripple every 0.15–0.4 seconds
        _rippleSpawnTimer = 0.15 + _rng.nextDouble() * 0.25;
      }

      // Update existing ripples, remove dead ones
      _ripples.removeWhere((r) => r.update(dt));
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
        _floodAmbient(canvas, sw, sh);
        _rain(canvas, sw, sh, count: 200);
        _floodRipples(canvas);
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

  // ─── Flood: Ambient water overlay + breathing ──────────────

  void _floodAmbient(Canvas canvas, double w, double h) {
    // Breathing effect: slow sinusoidal alpha oscillation (0.40 – 0.55)
    // Using a very slow frequency (~0.4 Hz) for a calm, submerged feel
    final breathe = sin(_elapsed * 0.4) * 0.075; // oscillates ±0.075
    final alpha = (0.48 + breathe).clamp(0.0, 1.0);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = _floodAmbientBase.withValues(alpha: alpha),
    );
  }

  // ─── Flood: Ripple particles ──────────────────────────────

  void _floodRipples(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final ripple in _ripples) {
      if (ripple.alpha <= 0.01) continue;
      paint.color = _rippleColor.withValues(alpha: ripple.alpha);
      canvas.drawCircle(
        Offset(ripple.x, ripple.y),
        ripple.radius,
        paint,
      );
    }
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
