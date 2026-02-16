import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'mining_game.dart';
import 'tile_data.dart';
import 'attack_range_effect_component.dart';

enum MonsterAnim { idle, walk, jump, attack, hurt, death }

enum MonsterKind { pink, owlet, dude }

class MonsterStats {
  final int maxHp;
  final int meleeDamage;
  final int leapDamage;
  final int touchDamage;
  final double attackCooldown;
  final double speed;
  final double meleeCooldown;
  final double leapCooldown;
  final int goldReward;
  final int xpReward;

  const MonsterStats({
    required this.maxHp,
    required this.meleeDamage,
    required this.leapDamage,
    required this.touchDamage,
    required this.attackCooldown,
    required this.speed,
    required this.meleeCooldown,
    required this.leapCooldown,
    required this.goldReward,
    required this.xpReward,
  });
}

const Map<MonsterKind, MonsterStats> defaultMonsterStats = {
  MonsterKind.pink: MonsterStats(
    maxHp: 45,
    meleeDamage: 12,
    leapDamage: 18,
    touchDamage: 5,
    attackCooldown: 0.55,
    speed: 58,
    meleeCooldown: 0.9,
    leapCooldown: 2.3,
    goldReward: 7,
    xpReward: 14,
  ),
  MonsterKind.owlet: MonsterStats(
    maxHp: 32,
    meleeDamage: 10,
    leapDamage: 14,
    touchDamage: 4,
    attackCooldown: 0.45,
    speed: 85,
    meleeCooldown: 0.6,
    leapCooldown: 1.5,
    goldReward: 6,
    xpReward: 12,
  ),
  MonsterKind.dude: MonsterStats(
    maxHp: 72,
    meleeDamage: 18,
    leapDamage: 26,
    touchDamage: 8,
    attackCooldown: 0.7,
    speed: 46,
    meleeCooldown: 1.25,
    leapCooldown: 3.2,
    goldReward: 12,
    xpReward: 20,
  ),
};

class MonsterComponent extends SpriteAnimationGroupComponent<MonsterAnim>
    with HasGameReference<MiningGame> {
  final MonsterKind kind;
  final MonsterStats stats;
  final void Function(MonsterComponent)? onDeath;

  late int hp;
  final Vector2 velocity = Vector2.zero();

  bool _onGround = false;
  bool _isDying = false;
  bool _isMeleeAttacking = false;
  bool _isLeapingAttack = false;
  bool _didMeleeHit = false;

  double _hurtTimer = 0;
  double _meleeTimer = 0;
  double _deathTimer = 0;
  double _attackCooldown = 0;
  double _meleeCooldown = 0;
  double _leapCooldown = 1.0;

  static const double _gravity = 900;
  static const double _maxFallSpeed = 700;
  static const double _jumpSpeed = 360;
  static const double _meleeRange = 34;
  static const double _leapMinRange = 70;
  static const double _leapMaxRange = 180;

  MonsterComponent({
    required Vector2 position,
    required this.kind,
    required Map<MonsterAnim, SpriteAnimation> animations,
    MonsterStats? stats,
    this.onDeath,
  }) : stats = stats ?? defaultMonsterStats[kind]!,
       super(
         position: position,
         size: Vector2.all(32),
         animations: animations,
         current: MonsterAnim.idle,
         priority: 5,
       ) {
    hp = this.stats.maxHp;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isDying) {
      _deathTimer += dt;
      if (_deathTimer >= 0.65) {
        removeFromParent();
      }
      return;
    }

    if (_meleeCooldown > 0) _meleeCooldown -= dt;
    if (_leapCooldown > 0) _leapCooldown -= dt;
    if (_attackCooldown > 0) _attackCooldown -= dt;
    if (_hurtTimer > 0) _hurtTimer -= dt;

    final player = game.player;
    final dx = player.center.x - center.x;
    final dy = player.center.y - center.y;
    final absDx = dx.abs();
    final absDy = dy.abs();

    if (_hurtTimer <= 0 && !_isMeleeAttacking) {
      if (_onGround &&
          _attackCooldown <= 0 &&
          _meleeCooldown <= 0 &&
          absDx <= _meleeRange &&
          absDy <= tileSize) {
        _startMeleeAttack();
      } else if (_onGround &&
          _attackCooldown <= 0 &&
          _leapCooldown <= 0 &&
          absDx >= _leapMinRange &&
          absDx <= _leapMaxRange) {
        _startLeapAttack(dx.sign);
      } else {
        _chasePlayer(dx);
      }
    } else if (_hurtTimer > 0) {
      velocity.x = 0;
    }

    if (_isMeleeAttacking) {
      _meleeTimer -= dt;
      velocity.x = 0;
      if (!_didMeleeHit && _meleeTimer <= 0.16) {
        _didMeleeHit = true;
        _tryHitPlayer(stats.meleeDamage, _meleeRange + 4);
      }
      if (_meleeTimer <= 0) {
        _isMeleeAttacking = false;
      }
    }

    velocity.y += _gravity * dt;
    if (velocity.y > _maxFallSpeed) velocity.y = _maxFallSpeed;

    final wasOnGround = _onGround;
    _moveHorizontal(dt);
    _moveVertical(dt);
    final landed = !wasOnGround && _onGround;

    if (_isLeapingAttack && landed) {
      _tryHitPlayer(stats.leapDamage, _meleeRange + 10);
      _isLeapingAttack = false;
    }

    _syncAnimation();
  }

  void _chasePlayer(double dx) {
    if (_isLeapingAttack) return;
    if (dx.abs() <= 8) {
      velocity.x = 0;
      return;
    }

    final dir = dx.sign;
    final targetSpeed = stats.speed * dir;
    velocity.x = targetSpeed;

    if (_onGround) {
      final footY = position.y + size.y - 2;
      final aheadX = dir > 0 ? position.x + size.x + 1 : position.x - 1;
      final blocked =
          _isSolidAtWorld(aheadX, position.y + 4) ||
          _isSolidAtWorld(aheadX, position.y + size.y - 4);
      final hasGroundAhead = _isSolidAtWorld(aheadX, footY + tileSize * 0.6);

      if (blocked || !hasGroundAhead) {
        velocity.y = -_jumpSpeed;
        _onGround = false;
      }
    }
  }

  void _startMeleeAttack() {
    _isMeleeAttacking = true;
    _didMeleeHit = false;
    _meleeTimer = 0.34;
    _meleeCooldown = stats.meleeCooldown;
    _spawnAttackRangeFx(_meleeRange + 4, const Color(0xFFFF8A65));
  }

  void _startLeapAttack(double dir) {
    if (dir == 0) return;
    _isLeapingAttack = true;
    _leapCooldown = stats.leapCooldown;
    velocity.x = dir * (stats.speed + 55);
    velocity.y = -(_jumpSpeed + 20);
    _onGround = false;
  }

  void _tryHitPlayer(int damage, double range) {
    _spawnAttackRangeFx(range, const Color(0xFFFF7043));
    final player = game.player;
    final withinX = (player.center.x - center.x).abs() <= range;
    final withinY = (player.center.y - center.y).abs() <= tileSize;
    if (!withinX || !withinY) return;

    game.gameState.takeDamage(damage);
    _attackCooldown = stats.attackCooldown;
    final knockDir = (player.center.x - center.x).sign;
    if (knockDir != 0) {
      player.velocity.x += knockDir * 70;
    }
  }

  bool _isSolidAtWorld(double worldX, double worldY) {
    final tx = (worldX / tileSize).floor();
    final ty = (worldY / tileSize).floor();
    return game.worldManager.isSolid(tx, ty);
  }

  void _spawnAttackRangeFx(double range, Color color) {
    game.gameWorld.add(
      AttackRangeEffectComponent(
        center: center.clone(),
        radius: range,
        color: color,
      ),
    );
  }

  void _moveHorizontal(double dt) {
    if (velocity.x == 0) return;
    position.x += velocity.x * dt;

    if (velocity.x > 0) {
      final right = position.x + size.x - 1;
      final top = position.y + 3;
      final bottom = position.y + size.y - 3;
      if (_isSolidAtWorld(right, top) || _isSolidAtWorld(right, bottom)) {
        position.x = (right / tileSize).floor() * tileSize - size.x;
        velocity.x = 0;
      }
    } else {
      final left = position.x;
      final top = position.y + 3;
      final bottom = position.y + size.y - 3;
      if (_isSolidAtWorld(left, top) || _isSolidAtWorld(left, bottom)) {
        position.x = ((left / tileSize).floor() + 1) * tileSize;
        velocity.x = 0;
      }
    }
  }

  void _moveVertical(double dt) {
    _onGround = false;
    position.y += velocity.y * dt;

    if (velocity.y > 0) {
      final bottom = position.y + size.y;
      final left = position.x + 3;
      final right = position.x + size.x - 3;
      if (_isSolidAtWorld(left, bottom) || _isSolidAtWorld(right, bottom)) {
        position.y = (bottom / tileSize).floor() * tileSize - size.y;
        velocity.y = 0;
        _onGround = true;
      }
    } else if (velocity.y < 0) {
      final top = position.y;
      final left = position.x + 3;
      final right = position.x + size.x - 3;
      if (_isSolidAtWorld(left, top) || _isSolidAtWorld(right, top)) {
        position.y = ((top / tileSize).floor() + 1) * tileSize;
        velocity.y = 0;
      }
    }
  }

  void _syncAnimation() {
    if (_isDying) {
      current = MonsterAnim.death;
      return;
    }
    if (_hurtTimer > 0) {
      current = MonsterAnim.hurt;
      return;
    }
    if (_isMeleeAttacking) {
      current = MonsterAnim.attack;
      return;
    }
    if (!_onGround) {
      current = MonsterAnim.jump;
      return;
    }
    if (velocity.x.abs() > 6) {
      current = MonsterAnim.walk;
      return;
    }
    current = MonsterAnim.idle;
  }

  void takeDamage(int amount) {
    if (_isDying) return;
    hp -= amount;
    if (hp <= 0) {
      _isDying = true;
      _deathTimer = 0;
      current = MonsterAnim.death;
      velocity.setZero();
      game.gameState.addXp(stats.xpReward);
      game.gameState.gold += stats.goldReward;
      onDeath?.call(this);
      return;
    }

    _hurtTimer = 0.22;
    final knockDir = (center.x - game.player.center.x).sign;
    if (knockDir != 0) {
      velocity.x = knockDir * 90;
    }
  }
}
