import 'dart:ui';

import 'package:flame/components.dart';

import 'tile_data.dart';
import 'mining_game.dart';

enum FacingDir { left, right, up, down }

class PlayerComponent extends RectangleComponent
    with HasGameReference<MiningGame> {
  final Vector2 velocity = Vector2.zero();
  double _moveInput = 0;
  bool _onGround = false;
  double _fallStartY = 0;
  bool _wasFalling = false;

  /// true while the jump key / button is held
  bool jumpHeld = false;

  FacingDir facingDir = FacingDir.down;

  /// Horizontal offset for legacy place-facing logic.
  int get facingH => facingDir == FacingDir.left ? -1 : 1;

  static const double moveSpeed = 160;
  static const double gravity = 900;
  static const double jumpSpeed = 380;
  static const double fallDmgThreshold = tileSize * 5;
  static const double fallDmgMultiplier = 0.4;

  // Jetpack tuning
  static const double jetThrust = 1600;
  static const double jetMaxUp = 220;
  static const double jetFuelRate = 8; // per second
  static const double _jumpGrace = 0.25; // seconds after ground jump before jetpack kicks in
  double _jumpGraceTimer = 0;

  double get reach => tileSize * 2.8;
  int get depth => ((y / tileSize).floor() - skyRows).clamp(0, worldHeight);
  bool get isAtSurface => depth <= 2;

  PlayerComponent({required Vector2 position})
      : super(
          position: position,
          size: Vector2(22, 28),
          paint: Paint()..color = const Color(0xFF4CC9F0),
        );

  void setMoveInput(double v) {
    _moveInput = v.clamp(-1.0, 1.0);
    if (v > 0.1) facingDir = FacingDir.right;
    if (v < -0.1) facingDir = FacingDir.left;
  }

  @override
  void update(double dt) {
    super.update(dt);

    velocity.x = _moveInput * moveSpeed;
    velocity.y += gravity * dt;

    // Fall tracking
    if (velocity.y > 50 && !_wasFalling) {
      _fallStartY = position.y;
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

    // Reset colour when not thrusting
    if (!jumpHeld || _onGround || !gs.hasJetpack || gs.jetpackFuel <= 0) {
      paint.color = const Color(0xFF4CC9F0);
    }

    _step(dt, horizontal: true);
    _step(dt, horizontal: false);
  }

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
    _wasFalling = false;
    final dist = position.y - _fallStartY;
    if (dist > fallDmgThreshold) {
      final dmg = ((dist - fallDmgThreshold) * fallDmgMultiplier).round();
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
