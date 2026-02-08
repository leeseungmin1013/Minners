import 'dart:ui';

import 'package:flame/components.dart';

import 'tile_data.dart';
import 'mining_game.dart';

class TeleportDoor extends PositionComponent
    with HasGameReference<MiningGame> {
  final int id;
  double _time = 0;

  int get depth =>
      ((position.y / tileSize).floor() - skyRows).clamp(0, worldHeight);
  String get label => 'Door #$id  (Depth $depth)';

  TeleportDoor({required Vector2 position, required this.id})
      : super(position: position, size: Vector2.all(tileSize));

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    // Outer frame – pulsing purple
    final pulse = 0.6 + 0.4 * ((_time * 3).remainder(6.28)).abs().clamp(0, 1);
    final outer = Paint()
      ..color = Color.fromRGBO(153, 51, 255, pulse);
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(4)),
      outer,
    );

    // Inner glow
    final inner = Paint()..color = const Color(0x66FF66FF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, size.x - 8, size.y - 8),
        const Radius.circular(2),
      ),
      inner,
    );
  }
}
