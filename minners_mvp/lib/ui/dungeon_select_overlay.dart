import 'package:flutter/material.dart';

import '../game/dungeon_types.dart';
import '../game/mining_game.dart';

class DungeonSelectOverlay extends StatelessWidget {
  final MiningGame game;

  const DungeonSelectOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final specs = game.availableDungeonTypes();

    return Center(
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xEE101018),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF9C64FF), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Dungeon',
              style: TextStyle(
                color: Color(0xFFE0CCFF),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Lv ${game.gameState.level}  |  Tokens ${game.gameState.dungeonTokens}',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...specs.map((spec) => _buildTypeRow(context, spec)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  game.cancelDungeonSelection();
                },
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeRow(BuildContext context, DungeonTypeSpec spec) {
    final unlocked = game.gameState.level >= spec.unlockLevel;
    final monsters = spec.monsterWeights.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.key.name} ${(e.value * 100).round()}%')
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFF1B1B2A) : const Color(0xFF222222),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: unlocked ? const Color(0xFF5D88FF) : const Color(0xFF555555),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${spec.name}  (Lv ${spec.unlockLevel}+)',
                  style: TextStyle(
                    color: unlocked ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Waves ${spec.totalWaves} | Token ${spec.tokenPerWave}/wave',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  monsters,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: unlocked
                ? () {
                    game.startSelectedDungeon(spec.type);
                  }
                : null,
            child: Text(unlocked ? 'Enter' : 'Locked'),
          ),
        ],
      ),
    );
  }
}
