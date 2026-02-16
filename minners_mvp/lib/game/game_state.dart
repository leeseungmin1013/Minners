import 'dart:math';

import 'tile_data.dart';
import 'inventory.dart';
import 'dungeon_run.dart';

enum WorldMode { overworld, dungeon }

class GameState {
  int maxHp = 100;
  int hp = 100;
  int gold = 0;
  PickaxeTier pickaxeTier = PickaxeTier.wood;
  final Inventory inventory = Inventory();

  // Leveling
  int level = 0;
  int xp = 0;

  // Jetpack
  bool hasJetpack = false;
  bool jetpackEnabled = false;
  double jetpackFuel = 0;
  double jetpackMaxFuel = 100;

  // Combat
  bool isCombatMode = false;

  // Dungeon
  WorldMode worldMode = WorldMode.overworld;
  bool get inDungeon => worldMode == WorldMode.dungeon;
  set inDungeon(bool value) {
    worldMode = value ? WorldMode.dungeon : WorldMode.overworld;
  }

  int dungeonTokens = 0;
  int combatDamageBonusLevel = 0;
  int dungeonShieldCharges = 0;
  int activeShieldHits = 0;
  DungeonRunState? activeDungeonRun;

  int get miningDamage => pickaxeSpecs[pickaxeTier]!.damage;
  double get combatDamageMultiplier => 1.0 + (combatDamageBonusLevel * 0.05);
  int get xpToNextLevel => _xpNeededForLevel(level);

  int _xpNeededForLevel(int lvl) {
    const base = 50;
    const growth = 1.35;
    return max(1, (base * pow(growth, lvl)).round());
  }

  void addXp(int amount) {
    if (amount <= 0) return;
    xp += amount;
    if (xp >= xpToNextLevel) {
      level += 1;
      xp = 0;
    }
  }

  bool buyPickaxe(PickaxeTier tier) {
    final spec = pickaxeSpecs[tier]!;
    if (gold >= spec.cost && tier.index == pickaxeTier.index + 1) {
      gold -= spec.cost;
      pickaxeTier = tier;
      return true;
    }
    return false;
  }

  bool buyJetpack() {
    const cost = 2000;
    if (!hasJetpack && gold >= cost) {
      gold -= cost;
      hasJetpack = true;
      jetpackEnabled = true;
      jetpackFuel = jetpackMaxFuel;
      return true;
    }
    return false;
  }

  /// Refill fuel. Returns actual amount refilled.
  int refillFuel(int amount) {
    if (!hasJetpack) return 0;
    final space = (jetpackMaxFuel - jetpackFuel).ceil();
    final fill = amount.clamp(0, space);
    final cost = fill; // 1G per unit
    if (gold < cost) return 0;
    gold -= cost;
    jetpackFuel = (jetpackFuel + fill).clamp(0, jetpackMaxFuel);
    return fill;
  }

  bool buyItem(ItemType type, int count, int unitCost) {
    final total = unitCost * count;
    if (gold < total) return false;
    gold -= total;
    inventory.addItem(type, count);
    return true;
  }

  bool buyDungeonHpUpgrade() {
    const cost = 100;
    if (dungeonTokens < cost) return false;
    dungeonTokens -= cost;
    maxHp += 10;
    hp = (hp + 10).clamp(0, maxHp);
    return true;
  }

  bool buyCombatDamageUpgrade() {
    const cost = 140;
    if (dungeonTokens < cost) return false;
    dungeonTokens -= cost;
    combatDamageBonusLevel += 1;
    return true;
  }

  bool buyDungeonShieldCharge() {
    const cost = 60;
    if (dungeonTokens < cost) return false;
    dungeonTokens -= cost;
    dungeonShieldCharges += 1;
    return true;
  }

  void takeDamage(int damage) {
    if (activeShieldHits > 0) {
      activeShieldHits -= 1;
      return;
    }
    hp = (hp - damage).clamp(0, maxHp);
  }

  bool get isDead => hp <= 0;

  void die({bool keepInventory = false}) {
    if (!keepInventory) {
      for (final type in ItemType.values) {
        final total = inventory.countOf(type);
        if (total > 0) inventory.removeItem(type, total ~/ 2);
      }
    }
    hp = maxHp;
  }

  Map<String, dynamic> toJson() => {
    'hp': hp,
    'maxHp': maxHp,
    'gold': gold,
    'pickaxeTier': pickaxeTier.name,
    'level': level,
    'xp': xp,
    'hasJetpack': hasJetpack,
    'jetpackEnabled': jetpackEnabled,
    'jetpackFuel': jetpackFuel,
    'jetpackMaxFuel': jetpackMaxFuel,
    'worldMode': worldMode.name,
    'dungeonTokens': dungeonTokens,
    'combatDamageBonusLevel': combatDamageBonusLevel,
    'dungeonShieldCharges': dungeonShieldCharges,
    'activeShieldHits': activeShieldHits,
  };

  void loadFromJson(Map<String, dynamic> json) {
    hp = json['hp'] as int;
    maxHp = json['maxHp'] as int;
    gold = json['gold'] as int;
    pickaxeTier = PickaxeTier.values.firstWhere(
      (t) => t.name == json['pickaxeTier'],
      orElse: () => PickaxeTier.wood,
    );
    level = json['level'] as int? ?? 0;
    xp = json['xp'] as int? ?? 0;
    hasJetpack = json['hasJetpack'] as bool;
    jetpackEnabled = json['jetpackEnabled'] as bool? ?? hasJetpack;
    jetpackFuel = (json['jetpackFuel'] as num).toDouble();
    jetpackMaxFuel = (json['jetpackMaxFuel'] as num).toDouble();
    worldMode = WorldMode.values.firstWhere(
      (m) => m.name == (json['worldMode'] as String?),
      orElse: () => WorldMode.overworld,
    );
    dungeonTokens = json['dungeonTokens'] as int? ?? 0;
    combatDamageBonusLevel = json['combatDamageBonusLevel'] as int? ?? 0;
    dungeonShieldCharges = json['dungeonShieldCharges'] as int? ?? 0;
    activeShieldHits = json['activeShieldHits'] as int? ?? 0;
  }
}
