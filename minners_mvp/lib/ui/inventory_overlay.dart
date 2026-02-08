import 'package:flutter/material.dart';

import '../game/mining_game.dart';
import '../game/inventory.dart';
import '../game/tile_data.dart';
import '../game/game_state.dart';

class InventoryOverlay extends StatefulWidget {
  final MiningGame game;
  const InventoryOverlay({super.key, required this.game});

  @override
  State<InventoryOverlay> createState() => _InventoryOverlayState();
}

class _InventoryOverlayState extends State<InventoryOverlay> {
  GameState get _gs => widget.game.gameState;
  Inventory get _inv => _gs.inventory;

  int? _pickedGlobal;
  final Map<ItemType, int> _sellAmounts = {};

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        color: const Color(0xBB000000),
        child: Center(
          child: ListenableBuilder(
            listenable: _inv,
            builder: (_, _) => _buildPanel(),
          ),
        ),
      ),
    );
  }

  Widget _buildPanel() {
    return Container(
      width: 540,
      constraints: const BoxConstraints(maxHeight: 560),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xF01E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF555555)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Text('INVENTORY',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none)),
                ),
                Text('Gold: ${_gs.gold}  ',
                    style: const TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        decoration: TextDecoration.none)),
                _iconBtn(Icons.close, widget.game.closeInventory),
              ],
            ),
            const SizedBox(height: 8),

            // Main inventory (8x5)
            _sectionLabel('Backpack'),
            _buildGrid(_inv.main, hotbarCount),
            const SizedBox(height: 6),

            // Hotbar
            _sectionLabel('Hotbar'),
            _buildGrid(_inv.hotbar, 0),
            const SizedBox(height: 10),

            // Sell section
            _sectionLabel('Sell'),
            _buildSellSection(),
            const SizedBox(height: 10),

            // Shop section (surface only)
            if (widget.game.player.isAtSurface) ...[
              _sectionLabel('Shop (Surface)'),
              _buildShopSection(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Inventory grid ─────────────────────────────────────────────────────

  Widget _buildGrid(List<InvSlot> slots, int globalOffset) {
    final cols = 8;
    final rows = (slots.length / cols).ceil();
    return Column(
      children: List.generate(rows, (row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cols, (col) {
            final i = row * cols + col;
            if (i >= slots.length) return const SizedBox(width: 40, height: 40);
            return _buildInvSlot(slots[i], globalOffset + i);
          }),
        );
      }),
    );
  }

  Widget _buildInvSlot(InvSlot slot, int globalIndex) {
    final picked = _pickedGlobal == globalIndex;
    final isHotbar = globalIndex < hotbarCount;
    final isSelected = isHotbar && globalIndex == _inv.selected;

    final slotImg = (picked || isSelected)
        ? 'assets/images/ui/hotbar_selected.png'
        : 'assets/images/ui/hotbar_slot.png';

    return GestureDetector(
      onTap: () => _onSlotTap(globalIndex),
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(1),
        child: Stack(
          children: [
            Image.asset(
              slotImg,
              width: 40,
              height: 40,
              filterQuality: FilterQuality.none,
              fit: BoxFit.fill,
            ),
            if (!slot.isEmpty) ...[
              Center(
                child: _slotIcon(slot.type!, 24),
              ),
              Positioned(
                right: 2,
                bottom: 1,
                child: Text(
                  '${slot.count}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                    shadows: [
                      Shadow(offset: Offset(1, 1), blurRadius: 1),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onSlotTap(int globalIndex) {
    setState(() {
      if (_pickedGlobal == null) {
        if (!_inv.slotAt(globalIndex).isEmpty) {
          _pickedGlobal = globalIndex;
        }
      } else {
        _inv.moveSlot(_inv.slotAt(_pickedGlobal!), _inv.slotAt(globalIndex));
        _pickedGlobal = null;
      }
    });
  }

  // ── Sell section ───────────────────────────────────────────────────────

  Widget _buildSellSection() {
    final summary = _inv.summary;
    if (summary.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No items to sell',
            style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.normal)),
      );
    }

    return Column(
      children: summary.entries.map((e) => _buildSellRow(e.key, e.value)).toList(),
    );
  }

  Widget _buildSellRow(ItemType type, int total) {
    final spec = itemSpecs[type]!;
    final amt = (_sellAmounts[type] ?? 1).clamp(1, total);
    _sellAmounts[type] = amt;
    final goldEarned = amt * spec.sellValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _slotIcon(type, 16),
          const SizedBox(width: 6),
          SizedBox(
            width: 80,
            child: Text(
              '${spec.name} x$total',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.normal),
            ),
          ),
          _smallBtn('-10', () => _setSellAmt(type, amt - 10, total)),
          _smallBtn('-1', () => _setSellAmt(type, amt - 1, total)),
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              '$amt',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none),
            ),
          ),
          _smallBtn('+1', () => _setSellAmt(type, amt + 1, total)),
          _smallBtn('+10', () => _setSellAmt(type, amt + 10, total)),
          const SizedBox(width: 4),
          _smallBtn('All', () => _setSellAmt(type, total, total)),
          const SizedBox(width: 4),
          SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _gs.gold += _inv.sell(type, amt);
                  _sellAmounts.remove(type);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text('${goldEarned}G',
                  style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  void _setSellAmt(ItemType type, int value, int max) {
    setState(() {
      _sellAmounts[type] = value.clamp(1, max);
    });
  }

  // ── Shop section ───────────────────────────────────────────────────────

  Widget _buildShopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pickaxe / drill upgrades
        ...PickaxeTier.values.map(_buildPickaxeRow),
        const SizedBox(height: 8),

        // Jetpack
        _buildJetpackRow(),
        if (_gs.hasJetpack) _buildFuelRow(),
        const SizedBox(height: 8),

        // Consumables
        _sectionLabel('Buy Items'),
        _buildBuyItemRow(ItemType.tnt, 100),
        _buildBuyItemRow(ItemType.teleportGen, 500),
        _buildBuyItemRow(ItemType.bedrockBlock, 1000),
        const SizedBox(height: 6),

        // Heal
        if (_gs.hp < _gs.maxHp) _buildHealRow(),
      ],
    );
  }

  Widget _buildPickaxeRow(PickaxeTier tier) {
    final spec = pickaxeSpecs[tier]!;
    final current = _gs.pickaxeTier == tier;
    final owned = _gs.pickaxeTier.index >= tier.index;
    final next = tier.index == _gs.pickaxeTier.index + 1;
    final canBuy = next && _gs.gold >= spec.cost;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Image.asset(
            pickaxeIconPaths[tier]!,
            width: 16,
            height: 16,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${spec.name}  DMG ${spec.damage}',
              style: TextStyle(
                color: current ? const Color(0xFFFFD700) : Colors.white70,
                fontSize: 11,
                fontWeight: current ? FontWeight.bold : FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          if (current)
            _badge('EQUIPPED', const Color(0xFF4CAF50))
          else if (owned)
            _badge('OWNED', Colors.white24)
          else
            SizedBox(
              height: 24,
              child: ElevatedButton(
                onPressed: canBuy
                    ? () => setState(() => _gs.buyPickaxe(tier))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF333333),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                ),
                child: Text('${spec.cost}G',
                    style: TextStyle(
                        fontSize: 10,
                        color:
                            canBuy ? const Color(0xFFFFD700) : Colors.white24)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJetpackRow() {
    if (_gs.hasJetpack) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Image.asset(
              'assets/images/items/jetpack.png',
              width: 16,
              height: 16,
              filterQuality: FilterQuality.none,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text('Jetpack',
                  style: TextStyle(
                      color: Color(0xFFFFD700),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none)),
            ),
            _badge('OWNED', const Color(0xFF4CAF50)),
          ],
        ),
      );
    }

    final canBuy = _gs.gold >= 2000;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Image.asset(
            'assets/images/items/jetpack.png',
            width: 16,
            height: 16,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('Jetpack  (Hold jump to fly)',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    decoration: TextDecoration.none)),
          ),
          SizedBox(
            height: 24,
            child: ElevatedButton(
              onPressed: canBuy
                  ? () => setState(() => _gs.buyJetpack())
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text('2000G',
                  style: TextStyle(
                      fontSize: 10,
                      color: canBuy
                          ? const Color(0xFFFFD700)
                          : Colors.white24)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuelRow() {
    final fuel = _gs.jetpackFuel;
    final max = _gs.jetpackMaxFuel;
    final missing = (max - fuel).ceil();
    if (missing <= 0) {
      return Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Row(
          children: [
            Image.asset(
              'assets/images/items/fuel.png',
              width: 12,
              height: 12,
              filterQuality: FilterQuality.none,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Fuel: ${fuel.round()} / ${max.round()} (FULL)',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal),
              ),
            ),
          ],
        ),
      );
    }

    final canBuy = _gs.gold >= missing;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          Image.asset(
            'assets/images/items/fuel.png',
            width: 12,
            height: 12,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Fuel: ${fuel.round()} / ${max.round()}',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.normal),
            ),
          ),
          SizedBox(
            height: 22,
            child: ElevatedButton(
              onPressed: canBuy
                  ? () => setState(() => _gs.refillFuel(missing))
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFAA44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text('Refill ${missing}G',
                  style: const TextStyle(fontSize: 10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyItemRow(ItemType type, int unitCost) {
    final spec = itemSpecs[type]!;
    final canBuy = _gs.gold >= unitCost;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _slotIcon(type, 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              spec.name,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.normal),
            ),
          ),
          SizedBox(
            height: 24,
            child: ElevatedButton(
              onPressed: canBuy
                  ? () => setState(() => _gs.buyItem(type, 1, unitCost))
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text('${unitCost}G',
                  style: TextStyle(
                      fontSize: 10,
                      color: canBuy
                          ? const Color(0xFFFFD700)
                          : Colors.white24)),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 24,
            child: ElevatedButton(
              onPressed: _gs.gold >= unitCost * 10
                  ? () => setState(() => _gs.buyItem(type, 10, unitCost))
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF333333),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
              ),
              child: Text('x10 ${unitCost * 10}G',
                  style: TextStyle(
                      fontSize: 10,
                      color: _gs.gold >= unitCost * 10
                          ? const Color(0xFFFFD700)
                          : Colors.white24)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealRow() {
    final missing = _gs.maxHp - _gs.hp;
    final cost = (missing * 0.5).ceil();
    final canHeal = _gs.gold >= cost;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('Heal $missing HP',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.normal)),
          ),
          SizedBox(
            height: 26,
            child: ElevatedButton(
              onPressed: canHeal
                  ? () => setState(() {
                        _gs.gold -= cost;
                        _gs.hp = _gs.maxHp;
                      })
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4444),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
              ),
              child: Text('${cost}G', style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none)),
        ),
      );

  Widget _smallBtn(String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 22,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.normal)),
        ),
      );

  Widget _iconBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      );

  Widget _badge(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: c),
        ),
        child: Text(text,
            style: TextStyle(
                color: c,
                fontSize: 9,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.normal)),
      );

  Widget _slotIcon(ItemType type, double size) {
    final path = itemIconPaths[type];
    if (path == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: itemSpecs[type]?.color ?? const Color(0xFF888888),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }
    return Image.asset(
      path,
      width: size,
      height: size,
      filterQuality: FilterQuality.none,
    );
  }
}
