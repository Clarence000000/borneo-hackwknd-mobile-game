import 'package:flutter/material.dart';

/// Camera controller for pan and zoom on the isometric grid.
///
/// Wraps offset + scale and provides world ↔ screen conversions
/// that account for the current camera transform.
class GameCamera {
  /// Current pan offset in screen space.
  Offset offset;

  /// Current zoom level (1.0 = default).
  double scale;

  /// Zoom limits.
  static const double minScale = 0.5;
  static const double maxScale = 2.5;

  GameCamera({
    this.offset = Offset.zero,
    this.scale = 1.0,
  });

  /// Convert a world-space position to screen-space given camera transform.
  Offset worldToScreen(Offset worldPos) {
    return (worldPos * scale) + offset;
  }

  /// Convert a screen-space tap position to world-space.
  Offset screenToWorld(Offset screenPos) {
    return (screenPos - offset) / scale;
  }

  /// Apply a pan delta (from [GestureDetector.onPanUpdate]).
  void pan(Offset delta) {
    offset += delta;
  }

  /// Apply a scale change anchored at [focalPoint] in screen space.
  void zoom(double newScale, Offset focalPoint) {
    final clampedScale = newScale.clamp(minScale, maxScale);
    if (clampedScale == scale) return;

    // Adjust offset so the focal point stays fixed on screen
    final worldFocal = screenToWorld(focalPoint);
    scale = clampedScale;
    offset = focalPoint - (worldFocal * scale);
  }

  /// Build the [Matrix4] transform for use with [Canvas.transform].
  Matrix4 get transformMatrix {
    return Matrix4.identity()
      ..storage[12] = offset.dx
      ..storage[13] = offset.dy
      ..storage[0] = scale
      ..storage[5] = scale;
  }

  /// Center the camera on a world-space rect within the given screen size.
  void centerOn(Rect worldBounds, Size screenSize) {
    // Fit the grid in the screen
    final scaleX = screenSize.width / worldBounds.width;
    final scaleY = screenSize.height / worldBounds.height;
    scale = (scaleX < scaleY ? scaleX : scaleY) * 0.85; // 85% to add margin
    scale = scale.clamp(minScale, maxScale);

    // Center
    final scaledCenter = Offset(
      worldBounds.center.dx * scale,
      worldBounds.center.dy * scale,
    );
    offset = Offset(
      screenSize.width / 2 - scaledCenter.dx,
      screenSize.height / 2 - scaledCenter.dy,
    );
  }
}
