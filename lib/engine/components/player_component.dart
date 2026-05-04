import 'package:flame/components.dart';

/// A movable player character on the farm map.
///
/// Controlled via [JoystickComponent] on mobile.
/// Sprite: `assets/images/cat_walk.png`.
class PlayerComponent extends SpriteComponent with HasGameReference {
  static const double speed = 80.0; // pixels per second

  /// External joystick reference (set by RichiFarmGame).
  JoystickComponent? joystick;

  /// Map pixel bounds for clamping.
  double mapWidth = 0;
  double mapHeight = 0;

  PlayerComponent();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    sprite = await Sprite.load('cat_walk.png');
    size = Vector2(16, 16);
    anchor = Anchor.center;

    // Render on top of crops.
    priority = 10;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (joystick == null) return;

    // Only move when joystick is actively being dragged.
    if (!joystick!.isDragged) return;

    final delta = joystick!.relativeDelta * speed * dt;
    position.add(delta);

    // Clamp to map bounds.
    if (mapWidth > 0 && mapHeight > 0) {
      position.x = position.x.clamp(0, mapWidth);
      position.y = position.y.clamp(0, mapHeight);
    }
  }
}
