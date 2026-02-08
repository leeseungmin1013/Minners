import 'package:flutter/material.dart';

import '../game/mining_game.dart';

class DeathOverlay extends StatelessWidget {
  final MiningGame game;
  const DeathOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
        decoration: BoxDecoration(
          color: const Color(0xEE1A0A0A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFF4444), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'YOU DIED',
              style: TextStyle(
                color: Color(0xFFFF4444),
                fontSize: 30,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Lost 50 % of resources',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 15,
                fontWeight: FontWeight.normal,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => game.closeDeath(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CC9F0),
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
              ),
              child:
                  const Text('Respawn', style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
      ),
    );
  }
}
