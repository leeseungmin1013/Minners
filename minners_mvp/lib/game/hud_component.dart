import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import 'tile_data.dart';
import 'game_state.dart';
import 'mining_game.dart';

class HudComponent extends PositionComponent with HasGameRef<MiningGame> {
  // ... existing code ...

  // Panel
  late final RectangleComponent _panelBg;

  // HP
  late final RectangleComponent _hpBarBg;
  late final RectangleComponent _hpBarFill;
  late final RectangleComponent _hpBarBorder;
  late final TextComponent _hpText;

  // Icons
  late final SpriteComponent _goldIcon;
  late final SpriteComponent _pickaxeIcon;
  late final SpriteComponent _depthIcon;
  late final SpriteComponent _fuelIcon;

  // Stats Text
  late final TextComponent _goldText;
  late final TextComponent _pickaxeText;
  late final TextComponent _depthText;

  // Fuel Bar
  late final PositionComponent _fuelGroup;
  late final RectangleComponent _fuelBarBg;
  late final RectangleComponent _fuelBarFill;
  late final RectangleComponent _fuelBarBorder;
  late final TextComponent _fuelLabel;

  // XP Bar (Top Right)
  late final PositionComponent _xpGroup;
  late final RectangleComponent _xpBarBg; // Background track
  late final RectangleComponent _xpBarFill; // Blue fill
  late final RectangleComponent _xpBarBorder;
  late final TextComponent _xpLabel;

  // State trackers
  int _cHp = -1, _cMax = -1, _cDepth = -1, _cGold = -1;
  // Pickaxe Tier tracking to update icon
  PickaxeTier? _cPickTier;

  double _cFuel = -1, _cMaxFuel = -1;

  int _cLevel = -1, _cXp = -1, _cXpNeed = -1;

  // Text Styles
  static const _font = 'monospace';
  static const _baseStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFFFFFFFF),
    fontFamily: _font,
    shadows: [
      Shadow(blurRadius: 2, color: Color(0xFF000000), offset: Offset(1, 1)),
    ],
  );
  static final _tpWhite = TextPaint(style: _baseStyle);
  static final _tpGold = TextPaint(
    style: _baseStyle.copyWith(color: const Color(0xFFFFD700)),
  );
  static final _tpFuel = TextPaint(
    style: _baseStyle.copyWith(color: const Color(0xFFFFAA44)),
  );
  static final _tpXp = TextPaint(
    style: _baseStyle.copyWith(color: const Color(0xFF7AD7FF)),
  );

  HudComponent() {
    position = Vector2(0, 0);
    size = Vector2(640, 360);
  }

  @override
  Future<void> onLoad() async {
    // -----------------------------------------------------------------------
    // 1. Stats Panel (Top Left)
    // -----------------------------------------------------------------------
    _panelBg = RectangleComponent(
      position: Vector2(8, 8),
      size: Vector2(140, 120),
      paint: Paint()..color = const Color(0x99000000), // Semi-transparent black
    );
    // Border for panel
    final panelBorder = RectangleComponent(
      position: Vector2.zero(),
      size: _panelBg.size,
      paint: Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _panelBg.add(panelBorder);

    // HP Bar
    _hpBarBg = RectangleComponent(
      position: Vector2(8, 8),
      size: Vector2(124, 14),
      paint: Paint()..color = const Color(0xFF440000),
    );
    _hpBarFill = RectangleComponent(
      position: Vector2(0, 0),
      size: Vector2(124, 14),
      paint: Paint()..color = const Color(0xFFFF0000),
    );
    _hpBarBorder = RectangleComponent(
      position: Vector2(0, 0),
      size: Vector2(124, 14),
      paint: Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _hpText = TextComponent(
      text: 'HP',
      textRenderer: _tpWhite.copyWith((style) => style.copyWith(fontSize: 10)),
      position: Vector2(62, 2),
      anchor: Anchor.topCenter,
      priority: 1,
    );
    _hpBarBg.addAll([_hpBarFill, _hpBarBorder, _hpText]);
    _panelBg.add(_hpBarBg);

    // Gold Row
    _goldIcon = SpriteComponent(
      sprite: Sprite(game.images.fromCache('items/block_gold.png')),
      position: Vector2(8, 30),
      size: Vector2(16, 16),
    );
    _goldText = TextComponent(
      text: '0',
      textRenderer: _tpGold,
      position: Vector2(30, 30),
    );
    _panelBg.addAll([_goldIcon, _goldText]);

    // Pickaxe Row
    _pickaxeIcon = SpriteComponent(
      sprite: Sprite(game.images.fromCache('items/pickaxe_wood.png')),
      position: Vector2(8, 52),
      size: Vector2(16, 16),
    );
    _pickaxeText = TextComponent(
      text: 'Wood Pickaxe',
      textRenderer: _tpWhite,
      position: Vector2(30, 52),
    );
    _panelBg.addAll([_pickaxeIcon, _pickaxeText]);

    // Depth Row
    _depthIcon = SpriteComponent(
      sprite: Sprite(game.images.fromCache('items/block_bedrock.png')),
      position: Vector2(8, 74),
      size: Vector2(16, 16),
    );
    _depthText = TextComponent(
      text: 'Depth: 0',
      textRenderer: _tpWhite,
      position: Vector2(30, 74),
    );
    _panelBg.addAll([_depthIcon, _depthText]);

    // Fuel Row (Hidden by default)
    _fuelGroup = PositionComponent(
      position: Vector2(8, 96),
      size: Vector2(124, 16),
    );

    _fuelIcon = SpriteComponent(
      sprite: Sprite(game.images.fromCache('items/fuel.png')),
      position: Vector2(0, 0),
      size: Vector2(16, 16),
    );

    _fuelBarBg = RectangleComponent(
      position: Vector2(22, 4),
      size: Vector2(100, 8),
      paint: Paint()..color = const Color(0xFF442200),
    );
    _fuelBarFill = RectangleComponent(
      size: Vector2(100, 8),
      paint: Paint()..color = const Color(0xFFFFAA44),
    );
    _fuelBarBorder = RectangleComponent(
      size: Vector2(100, 8),
      paint: Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _fuelBarBg.addAll([_fuelBarFill, _fuelBarBorder]);

    _fuelLabel = TextComponent(
      text: '',
      textRenderer: _tpFuel.copyWith((style) => style.copyWith(fontSize: 10)),
      position: Vector2(100 + 22.0, 0),
      anchor: Anchor.topRight,
    );

    _fuelGroup.addAll([_fuelIcon, _fuelBarBg, _fuelLabel]);

    // Do not add _fuelGroup initially unless we check state,
    // but better to handle visibility in updateFrom.
    // So distinct from previous version, we don't add it to _panelBg yet.

    add(_panelBg);

    // -----------------------------------------------------------------------
    // 2. XP Bar (Top Right)
    // -----------------------------------------------------------------------
    // The bar itself
    _xpGroup = PositionComponent(
      size: Vector2(160, 40),
      anchor: Anchor.topRight,
    );

    // XP Label
    _xpLabel = TextComponent(
      text: 'Lv 0',
      textRenderer: _tpXp,
      position: Vector2(80, 0), // center above bar
      anchor: Anchor.topCenter,
    );

    // XP Bar Track
    _xpBarBg = RectangleComponent(
      position: Vector2(0, 16),
      size: Vector2(160, 10),
      paint: Paint()..color = const Color(0xFF001133),
    );
    _xpBarFill = RectangleComponent(
      position: Vector2(0, 0),
      size: Vector2(160, 10),
      paint: Paint()..color = const Color(0xFF00AAFF),
    );
    _xpBarBorder = RectangleComponent(
      position: Vector2(0, 0),
      size: Vector2(160, 10),
      paint: Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _xpBarBg.addAll([_xpBarFill, _xpBarBorder]);

    _xpGroup.addAll([_xpLabel, _xpBarBg]);
    add(_xpGroup);

    // Initial Layout setup
    _layoutXp(Vector2(640, 360));
  }

  void _layoutXp(Vector2 size) {
    // Assuming logical size 640x360
    final w = size.x > 0 ? size.x : 640.0;
    _xpGroup.position = Vector2(w - 8, 8);
  }

  void updateFrom(GameState s, int depth) {
    // 1. HP
    if (s.hp != _cHp || s.maxHp != _cMax) {
      _cHp = s.hp;
      _cMax = s.maxHp;
      // Clamp R to 0..1
      final r = s.maxHp > 0 ? (s.hp / s.maxHp).clamp(0.0, 1.0) : 0.0;
      _hpBarFill.size.x = 124 * r;
      _hpText.text = '$_cHp/$_cMax';

      if (r > 0.6) {
        _hpBarFill.paint.color = const Color(0xFF44FF44);
      } else if (r > 0.3) {
        _hpBarFill.paint.color = const Color(0xFFFFAA00);
      } else {
        _hpBarFill.paint.color = const Color(0xFFFF4444);
      }
    }

    // 2. Gold
    if (s.gold != _cGold) {
      _cGold = s.gold;
      _goldText.text = '$_cGold G';
    }

    // 3. Pickaxe
    // Because pickaxe upgrades are rare, checking enum change is fine.
    if (s.pickaxeTier != _cPickTier) {
      _cPickTier = s.pickaxeTier;
      final spec = pickaxeSpecs[_cPickTier!]!;
      _pickaxeText.text = spec.name;

      // Map tier to icon path from tile_data, but strip 'assets/images/'
      // because Flame's images.fromCache expects path relative to assets/images/
      String? rawPath = pickaxeIconPaths[_cPickTier];
      if (rawPath != null && rawPath.startsWith('assets/images/')) {
        rawPath = rawPath.substring('assets/images/'.length);
      }

      try {
        if (rawPath != null) {
          _pickaxeIcon.sprite = Sprite(game.images.fromCache(rawPath));
        }
      } catch (e) {
        // Fallback or ignore if not loaded
      }
    }

    // 4. Depth
    if (depth != _cDepth) {
      _cDepth = depth;
      _depthText.text = 'Depth: $depth';
    }

    // 5. Fuel
    final hasJetpack = s.hasJetpack;
    if (hasJetpack) {
      if (_fuelGroup.parent == null) {
        _panelBg.add(_fuelGroup);
      }

      // Update fuel bar
      if (s.jetpackFuel != _cFuel || s.jetpackMaxFuel != _cMaxFuel) {
        _cFuel = s.jetpackFuel;
        _cMaxFuel = s.jetpackMaxFuel;
        final r = _cMaxFuel > 0 ? (_cFuel / _cMaxFuel).clamp(0.0, 1.0) : 0.0;
        _fuelBarFill.size.x = 100 * r;
        _fuelLabel.text = '${_cFuel.round()}/${_cMaxFuel.round()}';
      }
    } else {
      if (_fuelGroup.parent != null) {
        _fuelGroup.removeFromParent();
      }
    }

    // 6. XP
    final xpNeed = s.xpToNextLevel;
    if (s.level != _cLevel || s.xp != _cXp || xpNeed != _cXpNeed) {
      _cLevel = s.level;
      _cXp = s.xp;
      _cXpNeed = xpNeed;

      final r = xpNeed <= 0 ? 0.0 : (_cXp / xpNeed).clamp(0.0, 1.0);
      _xpBarFill.size.x = 160 * r;
      _xpLabel.text = 'Lv $_cLevel  ($_cXp/$_cXpNeed)';
    }
  }
}
