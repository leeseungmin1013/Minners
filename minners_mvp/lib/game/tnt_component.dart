import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'tile_data.dart';
import 'inventory.dart';
import 'mining_game.dart';

class TntComponent extends SpriteComponent
    with HasGameReference<MiningGame> {
  double timer = 3.0;
  static const int blastRadius = 4;
  static const int blastDamage = 30;

  TntComponent({required Vector2 position, required Sprite sprite})
      : super(
          position: position,
          size: Vector2.all(tileSize),
          sprite: sprite,
          paint: Paint()..color = const Color(0xFFFFFFFF),
        );

  @override
  void update(double dt) {
    super.update(dt);
    timer -= dt;

    // Flash faster as timer runs out
    if (timer < 1.5) {
      final flash = (timer * 8).floor() % 2 == 0;
      paint.color =
          flash ? const Color(0xFFFFFFFF) : const Color(0xFFFFFF66);
    }

    if (timer <= 0) {
      _explode();
      removeFromParent();
    }
  }

  void _explode() {
    final cx = (position.x / tileSize).floor();
    final cy = (position.y / tileSize).floor();
    final wm = game.worldManager;
    final inv = game.inventory;

    for (var dy = -blastRadius; dy <= blastRadius; dy++) {
      for (var dx = -blastRadius; dx <= blastRadius; dx++) {
        if (dx * dx + dy * dy > blastRadius * blastRadius) continue;
        final tx = cx + dx;
        final ty = cy + dy;
        final tileType = wm.destroyTile(tx, ty);
        if (tileType != null) {
          final item = tileDropItem(tileType);
          if (item != null) inv.addItem(item);
        }
      }
    }

    // Damage player if within blast range
    final pc = game.player.center;
    final tc = Vector2(
      (cx + 0.5) * tileSize,
      (cy + 0.5) * tileSize,
    );
    if (pc.distanceTo(tc) < blastRadius * tileSize) {
      game.gameState.takeDamage(blastDamage);
    }

    // Explosion visual effect
    final explosionSize = blastRadius * 2.0 * tileSize;
    final anim = game.buildExplosionAnimation();
    final explosion = SpriteAnimationComponent(
      animation: anim,
      position: Vector2(
        position.x + tileSize / 2 - explosionSize / 2,
        position.y + tileSize / 2 - explosionSize / 2,
      ),
      size: Vector2.all(explosionSize),
      priority: 15,
    )..removeOnFinish = true;
    game.gameCamera.world?.add(explosion);
  }
}
