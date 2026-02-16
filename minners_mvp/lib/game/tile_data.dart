import 'package:flutter/painting.dart';

// ── Constants ──────────────────────────────────────────────────────────────
const double tileSize = 32;
const int worldWidth = 80;
const int worldHeight = 200;
const int skyRows = 5;

// ── Tile Types ─────────────────────────────────────────────────────────────
enum TileType { grass, dirt, stone, copper, iron, gold, diamond, bedrock }

class TileSpec {
  final int maxHp;
  final Color color;
  final int sellValue;
  final String label;

  const TileSpec({
    required this.maxHp,
    required this.color,
    required this.sellValue,
    required this.label,
  });
}

const Map<TileType, TileSpec> tileSpecs = {
  TileType.grass: TileSpec(
    maxHp: 5,
    color: Color(0xFF4CAF50),
    sellValue: 0,
    label: 'Grass',
  ),
  TileType.dirt: TileSpec(
    maxHp: 10,
    color: Color(0xFF8B5A2B),
    sellValue: 1,
    label: 'Dirt',
  ),
  TileType.stone: TileSpec(
    maxHp: 18,
    color: Color(0xFF808080),
    sellValue: 2,
    label: 'Stone',
  ),
  TileType.copper: TileSpec(
    maxHp: 28,
    color: Color(0xFFB87333),
    sellValue: 5,
    label: 'Copper',
  ),
  TileType.iron: TileSpec(
    maxHp: 40,
    color: Color(0xFFB7410E),
    sellValue: 10,
    label: 'Iron',
  ),
  TileType.gold: TileSpec(
    maxHp: 55,
    color: Color(0xFFFFD700),
    sellValue: 25,
    label: 'Gold',
  ),
  TileType.diamond: TileSpec(
    maxHp: 75,
    color: Color(0xFF00E5FF),
    sellValue: 50,
    label: 'Diamond',
  ),
  TileType.bedrock: TileSpec(
    maxHp: 99999,
    color: Color(0xFF1A1A2E),
    sellValue: 0,
    label: 'Bedrock',
  ),
};

// ── Tile Instance Data ─────────────────────────────────────────────────────
class TileState {
  TileType type;
  double hp;
  TileState(this.type, this.hp);
}

// ── Pickaxe Tiers ──────────────────────────────────────────────────────────
enum PickaxeTier { wood, stone, iron, gold, diamond, drillMk1, drillMk2, drillMk3 }

class PickaxeSpec {
  final String name;
  final int damage;
  final int cost;
  final Color color;

  const PickaxeSpec({
    required this.name,
    required this.damage,
    required this.cost,
    required this.color,
  });
}

const Map<PickaxeTier, PickaxeSpec> pickaxeSpecs = {
  PickaxeTier.wood: PickaxeSpec(
    name: 'Wood Pickaxe',
    damage: 8,
    cost: 0,
    color: Color(0xFF8B4513),
  ),
  PickaxeTier.stone: PickaxeSpec(
    name: 'Stone Pickaxe',
    damage: 15,
    cost: 50,
    color: Color(0xFF808080),
  ),
  PickaxeTier.iron: PickaxeSpec(
    name: 'Iron Pickaxe',
    damage: 25,
    cost: 200,
    color: Color(0xFFB7410E),
  ),
  PickaxeTier.gold: PickaxeSpec(
    name: 'Gold Pickaxe',
    damage: 38,
    cost: 500,
    color: Color(0xFFFFD700),
  ),
  PickaxeTier.diamond: PickaxeSpec(
    name: 'Diamond Pickaxe',
    damage: 55,
    cost: 1500,
    color: Color(0xFF00E5FF),
  ),
  PickaxeTier.drillMk1: PickaxeSpec(
    name: 'Drill Mk1',
    damage: 85,
    cost: 3000,
    color: Color(0xFF00CC44),
  ),
  PickaxeTier.drillMk2: PickaxeSpec(
    name: 'Drill Mk2',
    damage: 130,
    cost: 6000,
    color: Color(0xFF00FF66),
  ),
  PickaxeTier.drillMk3: PickaxeSpec(
    name: 'Drill Mk3',
    damage: 200,
    cost: 12000,
    color: Color(0xFFFF00FF),
  ),
};

// ── Pickaxe icon paths ────────────────────────────────────────────────────
const Map<PickaxeTier, String> pickaxeIconPaths = {
  PickaxeTier.wood: 'assets/images/items/pickaxe_wood.png',
  PickaxeTier.stone: 'assets/images/items/pickaxe_stone.png',
  PickaxeTier.iron: 'assets/images/items/pickaxe_iron.png',
  PickaxeTier.gold: 'assets/images/items/pickaxe_gold.png',
  PickaxeTier.diamond: 'assets/images/items/pickaxe_diamond.png',
  PickaxeTier.drillMk1: 'assets/images/items/drill_mk1.png',
  PickaxeTier.drillMk2: 'assets/images/items/drill_mk2.png',
  PickaxeTier.drillMk3: 'assets/images/items/drill_mk3.png',
};

// ── Helper: position-based noise ───────────────────────────────────────────
double tileNoise(int x, int y, [int seed = 0]) {
  var n = (x + seed) * 73856093 ^ (y + seed) * 19349663;
  n = (n ^ (n >> 13)) * 0x5bd1e995;
  return ((n >> 16) & 0xFFFF) / 65535.0;
}

bool isOre(TileType t) =>
    t == TileType.copper ||
    t == TileType.iron ||
    t == TileType.gold ||
    t == TileType.diamond;

int oreXpForTile(TileType t) {
  if (!isOre(t)) return 0;
  // Scale XP with ore value (rarity/value driven)
  return tileSpecs[t]!.sellValue * 2;
}
