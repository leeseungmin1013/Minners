import 'package:flutter/material.dart';

import '../game/mining_game.dart';
import '../game/settings.dart';

class PauseOverlay extends StatefulWidget {
  final MiningGame game;
  final VoidCallback onQuitToMenu;

  const PauseOverlay({
    super.key,
    required this.game,
    required this.onQuitToMenu,
  });

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<PauseOverlay> {
  bool _saving = false;
  bool _saved = false;

  void _resume() {
    widget.game.resumeGame();
    widget.game.overlays.remove('pause');
  }

  Future<void> _saveGame() async {
    setState(() {
      _saving = true;
      _saved = false;
    });
    await widget.game.saveGame();
    if (mounted) {
      setState(() {
        _saving = false;
        _saved = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    }
  }

  Future<void> _saveAndQuit() async {
    setState(() => _saving = true);
    await widget.game.saveGame();
    widget.onQuitToMenu();
  }

  @override
  Widget build(BuildContext context) {
    final settings = GameSettings();
    return GestureDetector(
      onTap: () {}, // Absorb taps
      child: Container(
        color: const Color(0xCC000000),
        child: Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xF01E1E2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF555555)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                const Text(
                  'PAUSED',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 4,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 20),

                // Resume
                _actionButton(
                  label: 'Resume',
                  icon: Icons.play_arrow,
                  color: const Color(0xFF4CAF50),
                  onTap: _resume,
                ),
                const SizedBox(height: 8),

                // Save Game
                _actionButton(
                  label: _saving
                      ? 'Saving...'
                      : _saved
                          ? 'Saved!'
                          : 'Save Game',
                  icon: _saved ? Icons.check : Icons.save,
                  color: _saved
                      ? const Color(0xFF66BB6A)
                      : const Color(0xFF42A5F5),
                  onTap: _saving ? null : _saveGame,
                ),
                const SizedBox(height: 16),

                // Settings section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'SETTINGS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF888888),
                      letterSpacing: 2,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Music volume
                _volumeRow(
                  label: 'Music',
                  value: settings.musicVolume,
                  onChanged: (v) {
                    setState(() => settings.musicVolume = v);
                    settings.save();
                  },
                ),
                const SizedBox(height: 4),

                // SFX volume
                _volumeRow(
                  label: 'SFX',
                  value: settings.sfxVolume,
                  onChanged: (v) {
                    setState(() => settings.sfxVolume = v);
                    settings.save();
                  },
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 16),

                // Save & Quit
                _actionButton(
                  label: 'Save & Quit to Menu',
                  icon: Icons.exit_to_app,
                  color: const Color(0xFFFF6B6B),
                  onTap: _saving ? null : _saveAndQuit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color.withAlpha(50) : const Color(0xFF1A1A2E),
          foregroundColor: enabled ? Colors.white : const Color(0xFF555555),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: enabled ? color.withAlpha(100) : const Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }

  Widget _volumeRow({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFCCCCCC),
              decoration: TextDecoration.none,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFFFD166),
              inactiveTrackColor: const Color(0xFF333333),
              thumbColor: const Color(0xFFFFD166),
              overlayColor: const Color(0x33FFD166),
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value,
              min: 0,
              max: 1,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '${(value * 100).round()}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF999999),
              decoration: TextDecoration.none,
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
