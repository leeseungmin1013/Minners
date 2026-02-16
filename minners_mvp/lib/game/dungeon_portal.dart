import 'package:flame/components.dart';
import 'tile_data.dart';

class DungeonPortal extends SpriteAnimationComponent {
  final int requiredLevel;
  final bool isExit;

  DungeonPortal({
    required Vector2 position,
    this.requiredLevel = 5,
    this.isExit = false,
    required SpriteAnimation animation,
  }) : super(
         position: position,
         size: Vector2(
           tileSize.toDouble(),
           tileSize.toDouble() * 2,
         ), // 1x2 blocks tall
         animation: animation,
         priority: 5,
       );
}
