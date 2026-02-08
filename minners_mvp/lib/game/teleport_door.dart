import 'package:flame/components.dart';

import 'tile_data.dart';

class TeleportDoor extends SpriteAnimationComponent {
  final int id;

  int get depth =>
      ((position.y / tileSize).floor() - skyRows).clamp(0, worldHeight);
  String get label => 'Door #$id  (Depth $depth)';

  TeleportDoor({
    required Vector2 position,
    required this.id,
    required SpriteAnimation animation,
  }) : super(position: position, size: Vector2.all(tileSize), animation: animation);
}
