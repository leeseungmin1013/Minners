import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../game/mining_game.dart';

class DungeonConfirmOverlay extends StatefulWidget {
  final MiningGame game;

  const DungeonConfirmOverlay({super.key, required this.game});

  @override
  State<DungeonConfirmOverlay> createState() => _DungeonConfirmOverlayState();
}

class _DungeonConfirmOverlayState extends State<DungeonConfirmOverlay> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Request focus to capture keyboard events (like 'T' or Enter)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _confirm() {
    widget.game.overlays.remove('dungeon_confirm');
    widget.game.confirmDungeonAction();
  }

  void _cancel() {
    widget.game.overlays.remove('dungeon_confirm');
    widget.game.cancelDungeonAction();
  }

  @override
  Widget build(BuildContext context) {
    // Determine title based on what sort of portal we are interacting with
    // We can infer context or pass it. For now, let's look at game state.
    final portal = widget.game.interactingPortal;
    final isExit = portal?.isExit ?? false;
    final requiredLevel = portal?.requiredLevel ?? 5;
    final title = isExit ? 'Return to Surface?' : 'Enter Dungeon?';
    final desc = isExit
        ? 'Dungeon progress will be saved (assets kept).'
        : 'Required Level: $requiredLevel+\nChoose dungeon type next.';

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyT ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            _confirm();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            _cancel();
          }
        }
      },
      child: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            border: Border.all(color: Colors.purpleAccent, width: 3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontSize: 32,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                desc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "(Press 'T' to Confirm)",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    onPressed: _cancel,
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                    onPressed: _confirm,
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
