import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'tile_data.dart';
import 'game_state.dart';

class HudComponent extends PositionComponent {
  late final RectangleComponent _hpBg;
  late final RectangleComponent _hpFill;
  late final TextComponent _hpLabel;
  late final TextComponent _depthText;
  late final TextComponent _goldText;
  late final TextComponent _pickaxeText;
  late final TextComponent _fuelText;

  int _cHp = -1, _cMax = -1, _cDepth = -1, _cGold = -1;
  String _cPick = '';
  String _cFuelText = '';

  static const _ts = TextStyle(
    fontSize: 11,
    color: Color(0xFFFFFFFF),
    fontFamily: 'monospace',
  );
  static final _tp = TextPaint(style: _ts);
  static final _tpGold =
      TextPaint(style: _ts.copyWith(color: const Color(0xFFFFD700)));
  static final _tpFuel =
      TextPaint(style: _ts.copyWith(color: const Color(0xFFFFAA44)));

  HudComponent() {
    position = Vector2(8, 6);
  }

  @override
  Future<void> onLoad() async {
    _hpBg = RectangleComponent(
      size: Vector2(100, 8),
      paint: Paint()..color = const Color(0xFF333333),
    );
    _hpFill = RectangleComponent(
      size: Vector2(100, 8),
      paint: Paint()..color = const Color(0xFF44FF44),
    );
    _hpLabel = TextComponent(
      text: '',
      textRenderer: _tp,
      position: Vector2(104, -1),
    );
    _depthText = TextComponent(
      text: '',
      textRenderer: _tp,
      position: Vector2(0, 12),
    );
    _goldText = TextComponent(
      text: '',
      textRenderer: _tpGold,
      position: Vector2(0, 24),
    );
    _pickaxeText = TextComponent(
      text: '',
      textRenderer: _tp,
      position: Vector2(0, 36),
    );
    _fuelText = TextComponent(
      text: '',
      textRenderer: _tpFuel,
      position: Vector2(0, 48),
    );
    addAll([_hpBg, _hpFill, _hpLabel, _depthText, _goldText, _pickaxeText, _fuelText]);
  }

  void updateFrom(GameState s, int depth) {
    if (s.hp != _cHp || s.maxHp != _cMax) {
      _cHp = s.hp;
      _cMax = s.maxHp;
      final r = s.hp / s.maxHp;
      _hpFill.size.x = 100 * r;
      _hpFill.paint.color = r > 0.6
          ? const Color(0xFF44FF44)
          : r > 0.3
              ? const Color(0xFFFFAA00)
              : const Color(0xFFFF4444);
      _hpLabel.text = '${s.hp}/${s.maxHp}';
    }
    if (depth != _cDepth) {
      _cDepth = depth;
      _depthText.text = 'Depth: $depth';
    }
    if (s.gold != _cGold) {
      _cGold = s.gold;
      _goldText.text = 'Gold: ${s.gold}';
    }
    final pn = pickaxeSpecs[s.pickaxeTier]!.name;
    if (pn != _cPick) {
      _cPick = pn;
      _pickaxeText.text = pn;
    }
    final ft = s.hasJetpack
        ? 'Fuel: ${s.jetpackFuel.round()}/${s.jetpackMaxFuel.round()}'
        : '';
    if (ft != _cFuelText) {
      _cFuelText = ft;
      _fuelText.text = ft;
    }
  }
}
