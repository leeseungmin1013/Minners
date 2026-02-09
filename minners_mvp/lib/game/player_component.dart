import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import 'tile_data.dart';
import 'mining_game.dart';

enum FacingDir { left, right, up, down, upLeft, upRight, downLeft, downRight }

class PlayerComponent extends SpriteComponent
    with HasGameReference<MiningGame> {
  final Vector2 velocity = Vector2.zero();
  double _moveInput = 0;
  bool _onGround = false;
  bool _wasFalling = false;

  /// true while the jump key / button is held
  bool jumpHeld = false;

  FacingDir _facingDir = FacingDir.down;
  FacingDir get facingDir => _facingDir;
  set facingDir(FacingDir dir) {
    if (_facingDir == dir) return;
    _facingDir = dir;
    _updateSpriteForDir();
  }

  // Directional sprites (from sprite sheet)
  final Sprite spriteRight;
  final Sprite spriteFront;
  final Sprite spriteUpRight;
  final Sprite spriteUp;
  bool _flipX = false;
  bool _flipY = false;

  // Gear sprites
  final Sprite gearPickaxe;
  final Sprite gearDrill;
  final Sprite gearJetpack;

  // Mining state (set by MiningGame each frame)
  bool isMining = false;
  PickaxeTier miningTier = PickaxeTier.wood;

  // Gear animation state
  double _swingTimer = 0;
  bool _isThrusting = false;
  bool _showJetpack = false;
  final Paint _gearPaint = Paint();

  // Swing animation tuning (pickaxe)
  static const double _swingSpeed = 10.0;
  static const double _swingAmplitude = 0.6;

  // Drill vibration tuning
  static const double _drillVibrateSpeed = 45.0;
  static const double _drillVibrateAmp = 2.0;
  static const double _drillVibratePerpSpeed = 37.0;
  static const double _drillVibratePerpAmp = 0.8;

  bool get _isDrill => miningTier.index >= PickaxeTier.drillMk1.index;

  /// Horizontal offset for legacy place-facing logic.
  int get facingH =>
      (_facingDir == FacingDir.left ||
              _facingDir == FacingDir.upLeft ||
              _facingDir == FacingDir.downLeft)
          ? -1
          : 1;

  static const double moveSpeed = 160;
  static const double gravity = 900;
  static const double jumpSpeed = 380;
  static const double fallDmgSpeedThreshold = 500;
  static const double fallDmgMultiplier = 0.05;

  // Jetpack tuning
  static const double jetThrust = 1600;
  static const double jetMaxUp = 220;
  static const double jetFuelRate = 8;
  static const double _jumpGrace = 0.25;
  double _jumpGraceTimer = 0;

  double get reach => tileSize * 2.8;
  int get depth => ((y / tileSize).floor() - skyRows).clamp(0, worldHeight);
  bool get isAtSurface => depth <= 2;

  PlayerComponent({
    required Vector2 position,
    required this.spriteRight,
    required this.spriteFront,
    required this.spriteUpRight,
    required this.spriteUp,
    required this.gearPickaxe,
    required this.gearDrill,
    required this.gearJetpack,
  }) : super(
          position: position,
          size: Vector2.all(24),
          sprite: null,
          paint: Paint()..color = const Color(0xFFFFFFFF),
        ) {
    _updateSpriteForDir();
  }

  void _updateSpriteForDir() {
    switch (_facingDir) {
      case FacingDir.right:
        sprite = spriteRight; _flipX = false; _flipY = false;
      case FacingDir.left:
        sprite = spriteRight; _flipX = true; _flipY = false;
      case FacingDir.down:
        sprite = spriteFront; _flipX = false; _flipY = false;
      case FacingDir.up:
        sprite = spriteUp; _flipX = false; _flipY = false;
      case FacingDir.upRight:
        sprite = spriteUpRight; _flipX = false; _flipY = false;
      case FacingDir.upLeft:
        sprite = spriteUpRight; _flipX = true; _flipY = false;
      case FacingDir.downRight:
        sprite = spriteUpRight; _flipX = false; _flipY = true;
      case FacingDir.downLeft:
        sprite = spriteUpRight; _flipX = true; _flipY = true;
    }
  }

  // ── Gear positioning ──────────────────────────────────────────────────

  /// Returns (offsetX, offsetY, baseAngle) for mining tool placement.
  /// Defined for canonical (unflipped) orientation; _flipX/_flipY mirrors automatically.
  (double, double, double) _toolTransform() {
    switch (_facingDir) {
      case FacingDir.right:
      case FacingDir.left:
        return (20, 8, -0.3);
      case FacingDir.down:
        return (18, 14, 0.5);
      case FacingDir.up:
        return (18, 2, -1.0);
      case FacingDir.upRight:
      case FacingDir.upLeft:
        return (20, 4, -0.7);
      case FacingDir.downRight:
      case FacingDir.downLeft:
        return (20, 12, 0.3);
    }
  }

  /// Returns (offsetX, offsetY) for jetpack placement on player's back.
  (double, double) _jetpackOffset() {
    switch (_facingDir) {
      case FacingDir.right:
      case FacingDir.left:
        return (-2, 4);
      case FacingDir.down:
        return (9, -2);
      case FacingDir.up:
        return (9, 14);
      case FacingDir.upRight:
      case FacingDir.upLeft:
        return (0, 8);
      case FacingDir.downRight:
      case FacingDir.downLeft:
        return (0, 2);
    }
  }

  double _swingAngle() => sin(_swingTimer * _swingSpeed) * _swingAmplitude;

  // ── Rendering ─────────────────────────────────────────────────────────

  @override
  // ignore: must_call_super – we render sprite manually with flip transforms
  void render(Canvas canvas) {
    canvas.save();

    // Apply flip transforms
    if (_flipX) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    if (_flipY) {
      canvas.translate(0, size.y);
      canvas.scale(1, -1);
    }

    // 1. Jetpack behind player (draw first when enabled)
    if (_showJetpack) {
      _renderJetpack(canvas);
    }

    // 2. Player body
    sprite?.render(canvas, size: size, overridePaint: paint);

    // 3. Mining tool in front of player (draw last)
    if (isMining) {
      if (_isDrill) {
        _renderDrill(canvas);
      } else {
        _renderPickaxe(canvas);
      }
    }

    canvas.restore();
  }

  void _renderJetpack(Canvas canvas) {
    final (ox, oy) = _jetpackOffset();

    // Thrust flame effect when actively thrusting
    if (_isThrusting) {
      final flamePaint = Paint()..color = const Color(0xCCFF8800);
      final flameH = 4.0 + sin(_swingTimer * 30) * 2.0;
      canvas.drawRect(
        Rect.fromLTWH(ox + 1, oy + 14, 6, flameH),
        flamePaint,
      );
    }

    gearJetpack.render(
      canvas,
      position: Vector2(ox, oy),
      size: Vector2(8, 14),
    );
  }

  void _renderPickaxe(Canvas canvas) {
    final (ox, oy, baseAngle) = _toolTransform();
    final totalAngle = baseAngle + _swingAngle();

    final tierColor = pickaxeSpecs[miningTier]!.color;
    _gearPaint.colorFilter = ColorFilter.mode(tierColor, BlendMode.modulate);

    const double gw = 14;
    const double gh = 14;

    canvas.save();
    canvas.translate(ox, oy);
    canvas.rotate(totalAngle);

    gearPickaxe.render(
      canvas,
      position: Vector2(-gw / 2, -gh),
      size: Vector2(gw, gh),
      overridePaint: _gearPaint,
    );

    canvas.restore();
  }

  void _renderDrill(Canvas canvas) {
    final (ox, oy, baseAngle) = _toolTransform();

    // Fix flip: negate angle in flipped canvas so orientation stays symmetric
    final angle = _flipX ? -baseAngle : baseAngle;

    // Drill vibration: rapid oscillation along drill axis and perpendicular
    final vibrateAlong = sin(_swingTimer * _drillVibrateSpeed) * _drillVibrateAmp;
    final vibratePerp = sin(_swingTimer * _drillVibratePerpSpeed) * _drillVibratePerpAmp;

    final tierColor = pickaxeSpecs[miningTier]!.color;
    _gearPaint.colorFilter = ColorFilter.mode(tierColor, BlendMode.modulate);

    const double gw = 14;
    const double gh = 14;

    canvas.save();
    canvas.translate(ox, oy);
    canvas.rotate(angle);
    // Vibration in drill-local space (X = along drill, Y = perpendicular)
    canvas.translate(vibrateAlong, vibratePerp);

    gearDrill.render(
      canvas,
      position: Vector2(0, -gh / 2),
      size: Vector2(gw, gh),
      overridePaint: _gearPaint,
    );

    canvas.restore();
  }

  // ── Input ─────────────────────────────────────────────────────────────

  void setMoveInput(double v) {
    _moveInput = v.clamp(-1.0, 1.0);
    if (v > 0.1) facingDir = FacingDir.right;
    if (v < -0.1) facingDir = FacingDir.left;
  }

  // ── Update ────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);

    velocity.x = _moveInput * moveSpeed;
    velocity.y += gravity * dt;

    // Fall tracking
    if (velocity.y > 50 && !_wasFalling) {
      _wasFalling = true;
    }

    final gs = game.gameState;

    if (_jumpGraceTimer > 0) _jumpGraceTimer -= dt;

    if (jumpHeld) {
      if (_onGround) {
        // Normal jump
        velocity.y = -jumpSpeed;
        _jumpGraceTimer = _jumpGrace;
      } else if (gs.hasJetpack &&
          gs.jetpackEnabled &&
          gs.jetpackFuel > 0 &&
          _jumpGraceTimer <= 0) {
        // Jetpack – only after grace period so normal jumps don't burn fuel
        velocity.y -= jetThrust * dt;
        velocity.y = velocity.y.clamp(-jetMaxUp, double.infinity);
        gs.jetpackFuel =
            (gs.jetpackFuel - jetFuelRate * dt).clamp(0, gs.jetpackMaxFuel);

        // Visual: lighter colour while thrusting
        paint.color = const Color(0xFFFFAA44);
      }
    }

    // Track thrusting state for gear rendering
    _isThrusting = jumpHeld &&
        !_onGround &&
        gs.hasJetpack &&
        gs.jetpackEnabled &&
        gs.jetpackFuel > 0 &&
        _jumpGraceTimer <= 0;

    // Show jetpack on back whenever enabled
    _showJetpack = gs.hasJetpack && gs.jetpackEnabled;

    // Reset colour when not thrusting
    if (!_isThrusting) {
      paint.color = const Color(0xFFFFFFFF);
    }

    // Swing animation
    if (isMining) {
      _swingTimer += dt;
    } else {
      _swingTimer = 0;
    }

    _step(dt, horizontal: true);
    _step(dt, horizontal: false);
  }

  // ── Physics ───────────────────────────────────────────────────────────

  void _step(double dt, {required bool horizontal}) {
    if (horizontal) {
      position.x += velocity.x * dt;
    } else {
      position.y += velocity.y * dt;
      _onGround = false;
    }
    _resolve(horizontal);
  }

  void _resolve(bool horizontal) {
    var r = _rect;
    final minX = (r.left / tileSize).floor();
    final maxX = (r.right / tileSize).floor();
    final minY = (r.top / tileSize).floor();
    final maxY = (r.bottom / tileSize).floor();

    for (var ty = minY; ty <= maxY; ty++) {
      for (var tx = minX; tx <= maxX; tx++) {
        if (!game.worldManager.isSolid(tx, ty)) continue;
        final tr = Rect.fromLTWH(
            tx * tileSize, ty * tileSize, tileSize, tileSize);
        if (!_rect.overlaps(tr)) continue;

        if (horizontal) {
          if (velocity.x > 0) {
            position.x = tr.left - size.x;
          } else if (velocity.x < 0) {
            position.x = tr.right;
          }
          velocity.x = 0;
        } else {
          if (velocity.y > 0) {
            position.y = tr.top - size.y;
            _applyFallDamage();
            _onGround = true;
          } else if (velocity.y < 0) {
            position.y = tr.bottom;
          }
          velocity.y = 0;
        }
        r = _rect;
      }
    }
    position.x = position.x.clamp(0, worldWidth * tileSize - size.x);
  }

  Rect get _rect => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  void _applyFallDamage() {
    if (!_wasFalling) return;
    final landingSpeed = velocity.y;
    _wasFalling = false;
    if (landingSpeed > fallDmgSpeedThreshold) {
      final dmg =
          ((landingSpeed - fallDmgSpeedThreshold) * fallDmgMultiplier).round();
      if (dmg > 0) game.gameState.takeDamage(dmg);
    }
  }

  void respawnAtSurface() {
    position
      ..x = worldWidth * tileSize / 2
      ..y = (skyRows - 2) * tileSize.toDouble();
    velocity.setZero();
    _wasFalling = false;
  }
}
