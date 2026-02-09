import 'tile_data.dart';
import 'inventory.dart';

class GameState {
  int maxHp = 100;
  int hp = 100;
  int gold = 0;
  PickaxeTier pickaxeTier = PickaxeTier.wood;
  final Inventory inventory = Inventory();

  // Jetpack
  bool hasJetpack = false;
  double jetpackFuel = 0;
  double jetpackMaxFuel = 100;

  int get miningDamage => pickaxeSpecs[pickaxeTier]!.damage;

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

  void takeDamage(int damage) {
    hp = (hp - damage).clamp(0, maxHp);
  }

  bool get isDead => hp <= 0;

  void die() {
    for (final type in ItemType.values) {
      final total = inventory.countOf(type);
      if (total > 0) inventory.removeItem(type, total ~/ 2);
    }
    hp = maxHp;
  }

  Map<String, dynamic> toJson() => {
        'hp': hp,
        'maxHp': maxHp,
        'gold': gold,
        'pickaxeTier': pickaxeTier.name,
        'hasJetpack': hasJetpack,
        'jetpackFuel': jetpackFuel,
        'jetpackMaxFuel': jetpackMaxFuel,
      };

  void loadFromJson(Map<String, dynamic> json) {
    hp = json['hp'] as int;
    maxHp = json['maxHp'] as int;
    gold = json['gold'] as int;
    pickaxeTier = PickaxeTier.values.firstWhere(
      (t) => t.name == json['pickaxeTier'],
      orElse: () => PickaxeTier.wood,
    );
    hasJetpack = json['hasJetpack'] as bool;
    jetpackFuel = (json['jetpackFuel'] as num).toDouble();
    jetpackMaxFuel = (json['jetpackMaxFuel'] as num).toDouble();
  }
}
