import 'package:flutter/material.dart';

import '../game/mining_game.dart';

class DungeonResultOverlay extends StatelessWidget {
  final MiningGame game;

  const DungeonResultOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final result = game.lastDungeonResult;
    if (result == null) return const SizedBox.shrink();

    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xEE101018),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: result.cleared
                ? const Color(0xFF6AFF9C)
                : const Color(0xFFFF7777),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.cleared ? 'Dungeon Cleared' : 'Dungeon Failed',
              style: TextStyle(
                color: result.cleared
                    ? const Color(0xFF6AFF9C)
                    : const Color(0xFFFF7777),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            _row('Type', result.type.name),
            _row('Reached Wave', '${result.reachedWave}'),
            _row('Earned', '${result.earnedTokens} token'),
            if (result.lostTokens > 0)
              _row('Lost', '-${result.lostTokens} token'),
            _row('Final', '${result.finalTokens} token'),
            const SizedBox(height: 8),
            _row('Balance', '${game.gameState.dungeonTokens} token'),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: game.closeDungeonResult,
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
