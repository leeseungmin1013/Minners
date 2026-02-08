import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'tile_data.dart';

// ── Item types ─────────────────────────────────────────────────────────────
enum ItemType {
  grassBlock,
  dirtBlock,
  stoneBlock,
  copperOre,
  ironOre,
  goldOre,
  diamondOre,
  bedrockBlock,
  tnt,
  teleportGen,
}

class ItemSpec {
  final String name;
  final Color color;
  final int sellValue;
  final bool isPlaceable;
  final TileType? tileType;

  const ItemSpec({
    required this.name,
    required this.color,
    required this.sellValue,
    this.isPlaceable = false,
    this.tileType,
  });
}

const Map<ItemType, ItemSpec> itemSpecs = {
  ItemType.grassBlock: ItemSpec(
    name: 'Grass',
    color: Color(0xFF4CAF50),
    sellValue: 1,
    isPlaceable: true,
    tileType: TileType.grass,
  ),
  ItemType.dirtBlock: ItemSpec(
    name: 'Dirt',
    color: Color(0xFF8B5A2B),
    sellValue: 1,
    isPlaceable: true,
    tileType: TileType.dirt,
  ),
  ItemType.stoneBlock: ItemSpec(
    name: 'Stone',
    color: Color(0xFF808080),
    sellValue: 2,
    isPlaceable: true,
    tileType: TileType.stone,
  ),
  ItemType.copperOre: ItemSpec(
    name: 'Copper Ore',
    color: Color(0xFFB87333),
    sellValue: 5,
  ),
  ItemType.ironOre: ItemSpec(
    name: 'Iron Ore',
    color: Color(0xFFB7410E),
    sellValue: 10,
  ),
  ItemType.goldOre: ItemSpec(
    name: 'Gold Ore',
    color: Color(0xFFFFD700),
    sellValue: 25,
  ),
  ItemType.diamondOre: ItemSpec(
    name: 'Diamond Ore',
    color: Color(0xFF00E5FF),
    sellValue: 50,
  ),
  ItemType.bedrockBlock: ItemSpec(
    name: 'Bedrock',
    color: Color(0xFF1A1A2E),
    sellValue: 500,
    isPlaceable: true,
    tileType: TileType.bedrock,
  ),
  ItemType.tnt: ItemSpec(
    name: 'TNT',
    color: Color(0xFFFF2222),
    sellValue: 50,
  ),
  ItemType.teleportGen: ItemSpec(
    name: 'Teleport Gen',
    color: Color(0xFF9933FF),
    sellValue: 200,
  ),
};

const Map<ItemType, String> itemIconPaths = {
  ItemType.grassBlock: 'assets/images/items/block_grass.png',
  ItemType.dirtBlock: 'assets/images/items/block_dirt.png',
  ItemType.stoneBlock: 'assets/images/items/block_stone.png',
  ItemType.copperOre: 'assets/images/items/block_copper.png',
  ItemType.ironOre: 'assets/images/items/block_iron.png',
  ItemType.goldOre: 'assets/images/items/block_gold.png',
  ItemType.diamondOre: 'assets/images/items/block_diamond.png',
  ItemType.bedrockBlock: 'assets/images/items/block_bedrock.png',
  ItemType.tnt: 'assets/images/items/tnt.png',
  ItemType.teleportGen: 'assets/images/items/teleport.png',
};

/// What item drops when a tile is mined.
ItemType? tileDropItem(TileType tile) {
  switch (tile) {
    case TileType.grass:
      return ItemType.grassBlock;
    case TileType.dirt:
      return ItemType.dirtBlock;
    case TileType.stone:
      return ItemType.stoneBlock;
    case TileType.copper:
      return ItemType.copperOre;
    case TileType.iron:
      return ItemType.ironOre;
    case TileType.gold:
      return ItemType.goldOre;
    case TileType.diamond:
      return ItemType.diamondOre;
    case TileType.bedrock:
      return null;
  }
}

// ── Constants ──────────────────────────────────────────────────────────────
const int maxStack = 512;
const int hotbarCount = 8;
const int mainRows = 5;
const int mainCols = 8;
const int mainCount = mainRows * mainCols; // 40

// ── Slot ───────────────────────────────────────────────────────────────────
class InvSlot {
  ItemType? type;
  int count;

  InvSlot() : type = null, count = 0;

  bool get isEmpty => type == null || count <= 0;
  bool get isFull => type != null && count >= maxStack;

  int add(ItemType t, int amount) {
    if (isEmpty) {
      type = t;
      final a = amount.clamp(0, maxStack);
      count = a;
      return a;
    }
    if (type != t) return 0;
    final space = maxStack - count;
    final a = amount.clamp(0, space);
    count += a;
    return a;
  }

  int remove(int amount) {
    final r = amount.clamp(0, count);
    count -= r;
    if (count <= 0) clear();
    return r;
  }

  void clear() {
    type = null;
    count = 0;
  }
}

// ── Inventory ──────────────────────────────────────────────────────────────
class Inventory extends ChangeNotifier {
  final List<InvSlot> hotbar = List.generate(hotbarCount, (_) => InvSlot());
  final List<InvSlot> main = List.generate(mainCount, (_) => InvSlot());
  int selected = 0;

  InvSlot get selectedSlot => hotbar[selected];

  List<InvSlot> get _all => [...hotbar, ...main];

  void select(int i) {
    selected = i.clamp(0, hotbarCount - 1);
    notifyListeners();
  }

  void scroll(int delta) {
    selected = (selected + delta) % hotbarCount;
    if (selected < 0) selected += hotbarCount;
    notifyListeners();
  }

  /// Add items. Returns leftover that couldn't fit.
  int addItem(ItemType type, [int amount = 1]) {
    var left = amount;
    // Stack existing
    for (final s in _all) {
      if (s.type == type && !s.isFull) {
        left -= s.add(type, left);
        if (left <= 0) break;
      }
    }
    // Empty slots
    if (left > 0) {
      for (final s in _all) {
        if (s.isEmpty) {
          left -= s.add(type, left);
          if (left <= 0) break;
        }
      }
    }
    notifyListeners();
    return left;
  }

  /// Remove items from any slot. Returns amount actually removed.
  int removeItem(ItemType type, int amount) {
    var left = amount;
    for (final s in [...main, ...hotbar]) {
      if (s.type == type && s.count > 0) {
        left -= s.remove(left);
        if (left <= 0) break;
      }
    }
    notifyListeners();
    return amount - left;
  }

  /// Remove from selected hotbar slot.
  int removeFromSelected([int amount = 1]) {
    final r = selectedSlot.remove(amount);
    notifyListeners();
    return r;
  }

  int countOf(ItemType type) {
    int t = 0;
    for (final s in _all) {
      if (s.type == type) t += s.count;
    }
    return t;
  }

  /// Sell [amount] of [type]. Returns gold earned.
  int sell(ItemType type, int amount) {
    final spec = itemSpecs[type];
    if (spec == null) return 0;
    final removed = removeItem(type, amount);
    return removed * spec.sellValue;
  }

  /// Move / swap two slots.
  void moveSlot(InvSlot from, InvSlot to) {
    if (identical(from, to)) return;
    if (to.isEmpty) {
      to.type = from.type;
      to.count = from.count;
      from.clear();
    } else if (from.type == to.type) {
      final space = maxStack - to.count;
      final moved = from.count.clamp(0, space);
      to.count += moved;
      from.count -= moved;
      if (from.count <= 0) from.clear();
    } else {
      final tt = to.type;
      final tc = to.count;
      to.type = from.type;
      to.count = from.count;
      from.type = tt;
      from.count = tc;
    }
    notifyListeners();
  }

  /// Global index: 0‑7 = hotbar, 8‑47 = main.
  InvSlot slotAt(int i) => i < hotbarCount ? hotbar[i] : main[i - hotbarCount];

  /// All unique item types currently held.
  Map<ItemType, int> get summary {
    final m = <ItemType, int>{};
    for (final s in _all) {
      if (!s.isEmpty) m[s.type!] = (m[s.type!] ?? 0) + s.count;
    }
    return m;
  }
}
