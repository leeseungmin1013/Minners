import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/mining_game.dart';
import 'ui/hotbar_overlay.dart';
import 'ui/inventory_overlay.dart';
import 'ui/death_overlay.dart';
import 'ui/teleport_overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const MiningApp());
}

class MiningApp extends StatefulWidget {
  const MiningApp({super.key});

  @override
  State<MiningApp> createState() => _MiningAppState();
}

class _MiningAppState extends State<MiningApp> {
  late final MiningGame _game = MiningGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Minners MVP',
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Listener(
            onPointerDown: (event) {
              if (event.buttons == kSecondaryMouseButton) {
                _game.handleRightClickDown(event.localPosition);
              }
            },
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _game.inventory
                    .scroll(event.scrollDelta.dy > 0 ? 1 : -1);
              }
            },
            child: GameWidget<MiningGame>(
              game: _game,
              autofocus: true,
              overlayBuilderMap: {
                'hotbar': (ctx, game) => HotbarOverlay(game: game),
                'inventory': (ctx, game) => InventoryOverlay(game: game),
                'death': (ctx, game) => DeathOverlay(game: game),
                'teleport': (ctx, game) => TeleportOverlay(game: game),
              },
              initialActiveOverlays: const ['hotbar'],
            ),
          ),
        ),
      ),
    );
  }
}
