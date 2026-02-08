import 'package:flutter/material.dart';

import '../game/mining_game.dart';
import '../game/inventory.dart';

class HotbarOverlay extends StatelessWidget {
  final MiningGame game;
  const HotbarOverlay({super.key, required this.game});

  Inventory get _inv => game.inventory;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ListenableBuilder(
          listenable: _inv,
          builder: (context, _) => _buildBar(),
        ),
      ),
    );
  }

  Widget _buildBar() {
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
              Center(
                child: _slotIcon(slot.type!),
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
