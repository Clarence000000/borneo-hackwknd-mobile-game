import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'package:farm_fintech/engine/forest_game.dart';

/// A forest NPC (oracle or trader) rendered in the ForestGame world.
///
/// Mirrors [ShadyLenderComponent]: sprite + [containsWorldPoint] hit-test.
/// Mirrors [LyraNpcComponent]: floating animated '!' when player is near.
class ForestNpcComponent extends SpriteComponent
    with HasGameReference<ForestGame> {
  final String npcName;
  bool isNearPlayer = false;

  double _animTime = 0.0;

  static const Map<String, String> _images = {
    'oracle': 'oracle.png',
    'trader': 'trader.png',
  };

  ForestNpcComponent({
    required this.npcName,
    required Vector2 npcPosition,
  }) : super(size: Vector2(32, 32), priority: 5) {
    position = npcPosition - Vector2(16, 16);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    sprite = await Sprite.load(_images[npcName] ?? 'oracle.png');
  }

  @override
  void update(double dt) {
    _animTime += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!isNearPlayer) return;

    // Floating '!' indicator — bobs vertically using sin wave.
    final floatY = math.sin(_animTime * 4.0) * 2.0;
    final cx = size.x / 2;
    final cy = -12.0 + floatY;

    // Yellow filled circle.
    canvas.drawCircle(
      Offset(cx, cy),
      7,
      Paint()..color = const ui.Color(0xFFFFD700),
    );
    // Dark border.
    canvas.drawCircle(
      Offset(cx, cy),
      7,
      Paint()
        ..color = const ui.Color(0xFF5D4037)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // '!' text centred on the circle.
    final tp = TextPainter(
      text: const TextSpan(
        text: '!',
        style: TextStyle(
          color: Color(0xFF2D1B10),
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  bool containsWorldPoint(double wx, double wy) =>
      wx >= position.x &&
      wx <= position.x + size.x &&
      wy >= position.y &&
      wy <= position.y + size.y;
}
