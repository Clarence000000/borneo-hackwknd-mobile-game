import 'dart:ui';
import 'package:flame/components.dart';
import 'package:farm_fintech/engine/richi_farm_game.dart';

/// A screen-space overlay that darkens the game during the night phase.
///
/// On the first frame after loading, the overlay snaps to the correct
/// brightness so a reload during nighttime doesn't flash bright then fade.
class NightOverlayComponent extends PositionComponent with HasGameReference<RichiFarmGame> {
  double _currentAlpha = 0.0;
  bool _initialised = false;
  
  // 0x99 alpha is roughly 0.6.
  final double _targetAlpha = 0.6; 
  
  // Controls the speed of the fade.
  // 0.25 alpha per second means it takes ~2.4 seconds to reach 0.6 (2-3 seconds gradient).
  final double _transitionSpeed = 0.25; 
  
  // Dark purple/blue color for the night overlay (rgb: 0, 0, 51)
  final Color _nightColor = const Color(0xFF000033);

  NightOverlayComponent() {
    // Highest priority to ensure it renders on top of everything in the viewport
    priority = 100;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Get the night status from game state (night is when isDaytime is false)
    final isNight = !game.gameState.isDaytime;
    final target = isNight ? _targetAlpha : 0.0;

    // On the very first frame, snap immediately to the correct alpha
    // so a reload during night doesn't flash bright then slowly darken.
    if (!_initialised) {
      _currentAlpha = target;
      _initialised = true;
      return;
    }

    // Smooth transition logic (gradient fade)
    if (_currentAlpha != target) {
      if (_currentAlpha < target) {
        _currentAlpha += _transitionSpeed * dt;
        if (_currentAlpha > target) _currentAlpha = target;
      } else {
        _currentAlpha -= _transitionSpeed * dt;
        if (_currentAlpha < target) _currentAlpha = target;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_currentAlpha > 0) {
      // Use game.size to cover the entire screen viewport
      canvas.drawRect(
        Rect.fromLTWH(0, 0, game.size.x, game.size.y),
        Paint()..color = _nightColor.withValues(alpha: _currentAlpha),
      );
    }
  }
}
