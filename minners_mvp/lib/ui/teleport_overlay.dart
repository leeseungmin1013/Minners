import 'package:flutter/material.dart';

import '../game/mining_game.dart';

class TeleportOverlay extends StatelessWidget {
  final MiningGame game;
  const TeleportOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final current = game.interactingDoor;
    final others =
        game.doors.where((d) => d.id != current?.id).toList();

    return GestureDetector(
      onTap: () {},
      child: Container(
        color: const Color(0xBB000000),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xF01E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF9933FF)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'TELEPORT',
                        style: TextStyle(
                          color: Color(0xFF9933FF),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    _iconBtn(Icons.close, game.closeTeleport),
                  ],
                ),
                if (current != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Text(
                      'From: ${current.label}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),

                // Spawn option
                _destButton(
                  label: 'Spawn (Surface)',
                  icon: Icons.home,
                  color: const Color(0xFF4CAF50),
                  onTap: () => game.teleportTo(null),
                ),
                const SizedBox(height: 4),

                // Other doors
                ...others.map((door) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _destButton(
                        label: door.label,
                        icon: Icons.door_front_door,
                        color: const Color(0xFF9933FF),
                        onTap: () => game.teleportTo(door),
                      ),
                    )),

                if (others.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No other doors placed yet',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        decoration: TextDecoration.none,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _destButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withAlpha(60),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }

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
}
