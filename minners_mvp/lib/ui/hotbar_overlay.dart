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
        decoration: BoxDecoration(
          color: const Color(0xFF222222),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? const Color(0xFFFFD700) : const Color(0xFF555555),
            width: selected ? 2 : 1,
          ),
        ),
        child: slot.isEmpty
            ? const SizedBox.shrink()
            : Stack(
                children: [
                  Center(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: itemSpecs[slot.type!]?.color ??
                            const Color(0xFF888888),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
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
              ),
      ),
    );
  }
}
