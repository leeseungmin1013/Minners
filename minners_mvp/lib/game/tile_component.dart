import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'tile_data.dart';

class TileComponent extends RectangleComponent {
  final int gridX;
  final int gridY;
  final TileState state;

  TileComponent({
    required this.gridX,
    required this.gridY,
    required this.state,
  }) : super(
          position: Vector2(gridX * tileSize, gridY * tileSize),
          size: Vector2.all(tileSize),
          paint: Paint()..color = _calcColor(state),
        );

  static Color _calcColor(TileState state) {
    final spec = tileSpecs[state.type]!;
    final ratio = state.hp / spec.maxHp;
    // Darken the tile proportionally to damage taken
    return Color.lerp(const Color(0xFF111111), spec.color, 0.3 + 0.7 * ratio)!;
  }

  void syncVisual() {
    paint.color = _calcColor(state);
  }
}
