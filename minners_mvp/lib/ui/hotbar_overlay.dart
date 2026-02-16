import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/mining_game.dart';
import '../game/inventory.dart';
import '../game/tile_data.dart';
import '../game/game_state.dart';

class HotbarOverlay extends StatefulWidget {
  final MiningGame game;
  const HotbarOverlay({super.key, required this.game});

  @override
  State<HotbarOverlay> createState() => _HotbarOverlayState();
}

class _HotbarOverlayState extends State<HotbarOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  Inventory get _inv => widget.game.inventory;
  GameState get _gs => widget.game.gameState;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildEquipSlot(),
            const SizedBox(width: 6),
            _buildHotbar(),
            if (_gs.hasJetpack) ...[
              const SizedBox(width: 6),
              _buildJetpackSlot(),
            ],
          ],
        ),
      ),
    );
  }

  // ── Equipment slot (pickaxe / drill) ──────────────────────────────────

  Widget _buildEquipSlot() {
    final tier = _gs.pickaxeTier;
    final iconPath = pickaxeIconPaths[tier]!;
    final isCombat = _gs.isCombatMode;

    return GestureDetector(
      onTap: () {
        setState(() {
          _gs.isCombatMode = !_gs.isCombatMode;
        });
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xAA111111),
          borderRadius: BorderRadius.circular(6),
          border: null,
        ),
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            Image.asset(
              'assets/images/ui/hotbar_slot.png',
              width: 32,
              height: 32,
              filterQuality: FilterQuality.none,
              fit: BoxFit.fill,
            ),
            Center(
              child: isCombat
                  ? Image.asset(
                      'assets/images/player/gear_sword.png', // Using sprite as icon for now
                      width: 22,
                      height: 22,
                      filterQuality: FilterQuality.none,
                      color: pickaxeSpecs[tier]!.color,
                      colorBlendMode: BlendMode.modulate,
                    )
                  : Image.asset(
                      iconPath,
                      width: 22,
                      height: 22,
                      filterQuality: FilterQuality.none,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Jetpack slot with fuel gauge ──────────────────────────────────────

  Widget _buildJetpackSlot() {
    final fuel = _gs.jetpackFuel;
    final maxFuel = _gs.jetpackMaxFuel;
    final enabled = _gs.jetpackEnabled;
    final depletedFraction = 1.0 - (fuel / maxFuel).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () => _gs.jetpackEnabled = !_gs.jetpackEnabled,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xAA111111),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled ? const Color(0xFFFF8800) : Colors.transparent,
            width: 2,
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              Image.asset(
                'assets/images/ui/hotbar_slot.png',
                width: 32,
                height: 32,
                filterQuality: FilterQuality.none,
                fit: BoxFit.fill,
              ),
              Center(
                child: Image.asset(
                  'assets/images/items/jetpack.png',
                  width: 22,
                  height: 22,
                  filterQuality: FilterQuality.none,
                ),
              ),
              // Fuel gauge: dark overlay from top when depleted
              if (depletedFraction > 0.01)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 32 * depletedFraction,
                    color: const Color(0xBB000000),
                  ),
                ),
              // OFF indicator when disabled
              if (!enabled)
                Container(
                  width: 32,
                  height: 32,
                  color: const Color(0x88000000),
                  alignment: Alignment.center,
                  child: const Text(
                    'OFF',
                    style: TextStyle(
                      fontSize: 9,
                      color: Color(0xAAFF4444),
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hotbar (existing) ─────────────────────────────────────────────────

  Widget _buildHotbar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xAA111111),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(hotbarCount, _buildSlot),
      ),
    );
  }

  Widget _buildSlot(int i) {
    final slot = _inv.hotbar[i];
    final selected = i == _inv.selected;

    return GestureDetector(
      onTap: () => _inv.select(i),
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        child: Stack(
          children: [
            Image.asset(
              selected
                  ? 'assets/images/ui/hotbar_selected.png'
                  : 'assets/images/ui/hotbar_slot.png',
              width: 38,
              height: 38,
              filterQuality: FilterQuality.none,
              fit: BoxFit.fill,
            ),
            if (!slot.isEmpty) ...[
              Center(child: _slotIcon(slot.type!)),
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
                    shadows: [Shadow(offset: Offset(1, 1), blurRadius: 1)],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _slotIcon(ItemType type) {
    final path = itemIconPaths[type];
    if (path == null) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: itemSpecs[type]?.color ?? const Color(0xFF888888),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }
    return Image.asset(
      path,
      width: 22,
      height: 22,
      filterQuality: FilterQuality.none,
    );
  }
}
