import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Lyra the Oracle — a static NPC sprite placed on the game map world.
///
/// Uses a single frame (frame 0, row 0) of character_14_frame32x32.png.
/// Tap detection is handled by [RichiFarmGame.handleTap] via [containsWorldPoint].
class LyraNpcComponent extends Component {
  final int gridCol;
  final int gridRow;

  // Display size: 2 tiles wide × 2 tiles tall (32×32 world units)
  static const double _spriteWorldSize = 32.0;
  static const int _frameSizePx = 32;

  final Vector2 position;
  ui.Image? _spriteSheet;
  ui.Image? _uiAsset;
  bool _loaded = false;
  double _animTime = 0.0;

  LyraNpcComponent({required this.gridCol, required this.gridRow})
      : position = Vector2(gridCol * 16.0, gridRow * 16.0);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      final data = await rootBundle.load('assets/images/character_14_frame32x32.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _spriteSheet = frame.image;

      final uiData = await rootBundle.load('assets/images/letter UI/UI assets pack 2/UI books & more.png');
      final uiCodec = await ui.instantiateImageCodec(uiData.buffer.asUint8List());
      final uiFrame = await uiCodec.getNextFrame();
      _uiAsset = uiFrame.image;

      _loaded = true;
    } catch (e) {
      developer.log('Failed to load Lyra assets: $e', name: 'LyraNpcComponent');
    }
  }

  @override
  void update(double dt) {
    _animTime += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!_loaded || _spriteSheet == null) {
      // Fallback: draw a colored rectangle
      canvas.drawRect(
        Rect.fromLTWH(position.x, position.y, _spriteWorldSize, _spriteWorldSize),
        Paint()..color = const ui.Color(0xFF9B59B6),
      );
      return;
    }

    // Draw frame 0 of row 0 (idle, front-facing)
    final src = Rect.fromLTWH(0, 0, _frameSizePx.toDouble(), _frameSizePx.toDouble());
    final dst = Rect.fromLTWH(
      position.x,
      position.y,
      _spriteWorldSize,
      _spriteWorldSize,
    );

    canvas.drawImageRect(
      _spriteSheet!,
      src,
      dst,
      Paint()..filterQuality = ui.FilterQuality.none,
    );

    // Subtle purple glow under the sprite
    canvas.drawRect(
      Rect.fromLTWH(position.x + 2, position.y + _spriteWorldSize - 4, _spriteWorldSize - 4, 4),
      Paint()
        ..color = const ui.Color(0x669B59B6)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
    );

    // Floating Exclamation Mark (!) from UI books assets
    if (_uiAsset != null) {
      final floatY = ui.lerpDouble(-2.0, 2.0, (math.sin(_animTime * 4.0) + 1) / 2) ?? 0;
      // Exclamation Bubble (!) in UI books & more.png is around (606, 458, 16, 16)
      // Actually let's use a standard icon block coordinate for speech bubbles
      final bubbleSrc = Rect.fromLTWH(606, 458, 16, 16);
      final bubbleDst = Rect.fromLTWH(
        position.x + 8, 
        position.y - 18 + floatY, 
        16, 
        16
      );
      canvas.drawImageRect(
        _uiAsset!,
        bubbleSrc,
        bubbleDst,
        Paint()..filterQuality = ui.FilterQuality.none,
      );
    }
  }

  /// Check if a world-space point is inside Lyra's hit area.
  bool containsWorldPoint(double worldX, double worldY) {
    return worldX >= position.x &&
        worldX <= position.x + _spriteWorldSize &&
        worldY >= position.y &&
        worldY <= position.y + _spriteWorldSize;
  }
}
