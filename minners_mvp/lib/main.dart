import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/mining_game.dart';
import 'game/save_data.dart';
import 'game/settings.dart';
import 'ui/hotbar_overlay.dart';
import 'ui/inventory_overlay.dart';
import 'ui/death_overlay.dart';
import 'ui/teleport_overlay.dart';
import 'ui/pause_overlay.dart';
import 'ui/main_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await GameSettings().load();
  runApp(const MiningApp());
}

enum AppScreen { mainMenu, playing }

class MiningApp extends StatefulWidget {
  const MiningApp({super.key});

  @override
  State<MiningApp> createState() => _MiningAppState();
}

class _MiningAppState extends State<MiningApp> {
  AppScreen _screen = AppScreen.mainMenu;
  MiningGame? _game;

  void _startNewGame() {
    setState(() {
      _game = MiningGame();
      _screen = AppScreen.playing;
    });
  }

  void _loadGame(SaveData saveData) {
    setState(() {
      _game = MiningGame(initialSaveData: saveData);
      _screen = AppScreen.playing;
    });
  }

  void _returnToMenu() {
    setState(() {
      _game = null;
      _screen = AppScreen.mainMenu;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Minners MVP',
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _screen == AppScreen.mainMenu
              ? MainMenu(
                  onNewGame: _startNewGame,
                  onLoadGame: _loadGame,
                )
              : _buildGameView(),
        ),
      ),
    );
  }

  Widget _buildGameView() {
    return Listener(
      onPointerDown: (event) {
        if (event.buttons == kSecondaryMouseButton) {
          _game!.handleRightClickDown(event.localPosition);
        }
      },
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          _game!.inventory.scroll(event.scrollDelta.dy > 0 ? 1 : -1);
        }
      },
      child: GameWidget<MiningGame>(
        key: ValueKey(_game),
        game: _game!,
        autofocus: true,
        overlayBuilderMap: {
          'hotbar': (ctx, game) => HotbarOverlay(game: game),
          'inventory': (ctx, game) => InventoryOverlay(game: game),
          'death': (ctx, game) => DeathOverlay(game: game),
          'teleport': (ctx, game) => TeleportOverlay(game: game),
          'pause': (ctx, game) => PauseOverlay(
                game: game,
                onQuitToMenu: _returnToMenu,
              ),
        },
        initialActiveOverlays: const ['hotbar'],
      ),
    );
  }
}
