import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'tile_data.dart';

class TileComponent extends SpriteComponent {
  final int gridX;
  final int gridY;
  final TileState state;
  final SpriteComponent _crackOverlay;

  static late Map<TileType, Sprite> _tileSprites;
  static late List<Sprite> _crackSprites;

  static void configure({
    required Map<TileType, Sprite> tileSprites,
    required List<Sprite> crackSprites,
  }) {
    _tileSprites = tileSprites;
    _crackSprites = crackSprites;
  }

  TileComponent({
    required this.gridX,
    required this.gridY,
    required this.state,
  })  : _crackOverlay = SpriteComponent(
          sprite: _crackSprites.first,
          size: Vector2.all(tileSize),
          priority: 1,
          paint: Paint()..color = const Color(0x00000000),
        ),
        super(
          position: Vector2(gridX * tileSize, gridY * tileSize),
          size: Vector2.all(tileSize),
          sprite: _tileSprites[state.type],
          paint: Paint()..color = _calcColor(state),
        ) {
    add(_crackOverlay);
    syncVisual();
  }

  static Color _calcColor(TileState state) {
    final spec = tileSpecs[state.type]!;
    final ratio = state.hp / spec.maxHp;
    // Darken the tile proportionally to damage taken
    return Color.lerp(const Color(0xFF111111), spec.color, 0.3 + 0.7 * ratio)!;
  }

  void syncVisual() {
    paint.color = _calcColor(state);
    final spec = tileSpecs[state.type]!;
    final damageRatio = 1.0 - (state.hp / spec.maxHp);
    final crackIndex = _crackIndex(damageRatio);
    if (crackIndex < 0) {
      _crackOverlay.paint.color = const Color(0x00000000);
    } else {
      _crackOverlay.sprite = _crackSprites[crackIndex];
      _crackOverlay.paint.color = const Color(0xFFFFFFFF);
    }
  }

  int _crackIndex(double damageRatio) {
    if (damageRatio < 0.25) return -1;
    if (damageRatio < 0.5) return 0;
    if (damageRatio < 0.75) return 1;
    if (damageRatio < 0.9) return 2;
    return 3;
  }
}
