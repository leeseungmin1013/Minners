import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tile_data.dart';
import 'game_state.dart';
import 'inventory.dart';
import 'player_component.dart';
import 'save_data.dart';
import 'save_manager.dart';
import 'tile_component.dart';
import 'world_manager.dart';
import 'hud_component.dart';
import 'tnt_component.dart';
import 'teleport_door.dart';
import 'monster_component.dart';
import 'dungeon_portal.dart';
import 'dungeon_types.dart';
import 'dungeon_run.dart';
import 'attack_range_effect_component.dart';

/// Outline drawn on the tile the player is currently facing,
/// with a green clockwise progress indicator for mining.
class _FacingOutline extends PositionComponent {
  bool visible = false;

  /// Mining progress 0.0 – 1.0 (0 = full HP, 1 = about to break).
  double miningProgress = 0;

  final Paint _whitePaint = Paint()
    ..color = const Color(0xCCFFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  final Paint _greenPaint = Paint()
    ..color = const Color(0xFF00FF00)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;

  _FacingOutline() : super(size: Vector2.all(tileSize), priority: 10);

  @override
  void render(ui.Canvas canvas) {
    if (!visible) return;

    // White base outline
    canvas.drawRect(size.toRect(), _whitePaint);

    // Green clockwise progress overlay (from top-center)
    if (miningProgress <= 0) return;
    final p = miningProgress.clamp(0.0, 1.0);
    final s = tileSize;
    // Total perimeter = 4 * s. We trace clockwise starting from top-center.
    // Segments: top-center→top-right (0.5s), right edge (s),
    //           bottom edge (s), left edge (s), top-left→top-center (0.5s)
    final totalLen = 4.0 * s;
    final len = p * totalLen;

    final path = ui.Path();
    // Starting point: top center
    final midTop = s / 2;
    path.moveTo(midTop, 0);

    // Segment lengths: [0.5s, s, s, s, 0.5s]
    final segs = <List<double>>[
      [s, 0], // top-center → top-right
      [s, s], // top-right  → bottom-right
      [0, s], // bottom-right → bottom-left
      [0, 0], // bottom-left → top-left
      [midTop, 0], // top-left → top-center
    ];
    final segLens = [midTop, s, s, s, midTop];

    double remaining = len;
    double cx = midTop, cy = 0;
    for (var i = 0; i < segs.length && remaining > 0; i++) {
      final ex = segs[i][0];
      final ey = segs[i][1];
      final sl = segLens[i];
      if (remaining >= sl) {
        path.lineTo(ex, ey);
        cx = ex;
        cy = ey;
        remaining -= sl;
      } else {
        final t = remaining / sl;
        final nx = cx + (ex - cx) * t;
        final ny = cy + (ey - cy) * t;
        path.lineTo(nx, ny);
        remaining = 0;
      }
    }

    canvas.drawPath(path, _greenPaint);
  }
}

/// Invisible component that smoothly follows the player.
/// The camera targets this instead of the player directly.
class _CameraTarget extends PositionComponent {
  final PlayerComponent player;
  _CameraTarget({required this.player}) : super(size: Vector2.zero());

  @override
  void update(double dt) {
    super.update(dt);
    final dx = player.position.x - position.x;
    final dy = player.position.y - position.y;
    final dist = dx.abs() + dy.abs();
    if (dist < 0.5) {
      position.setFrom(player.position);
    } else {
      final speed = (4.0 + dist * 0.03).clamp(4.0, 25.0);
      final t = (speed * dt).clamp(0.0, 1.0);
      position.x += dx * t;
      position.y += dy * t;
    }
  }
}

enum DungeonFlowState {
  surface,
  selectingType,
  entering,
  activeWave,
  betweenWaves,
  cleared,
  escaping,
  recovering,
}

class MiningGame extends FlameGame with TapCallbacks {
  final SaveData? initialSaveData;
  final GameState gameState = GameState();
  late final WorldManager worldManager;
  late final PlayerComponent player;
  late final CameraComponent gameCamera;
  late final World gameWorld;
  late final _CameraTarget _cameraTarget;
  late final _FacingOutline _facingOutline;
  JoystickComponent? _joystick;
  HudComponent? _hud;
  late final Sprite _playerRight;
  late final Sprite _playerFront;
  late final Sprite _playerUpRight;
  late final Sprite _playerUp;
  late final Sprite _tntSprite;
  late final List<Sprite> _portalFrames;
  late final List<Sprite> _explosionFrames;
  late final Map<MonsterKind, Map<MonsterAnim, SpriteAnimation>>
  _monsterAnimations;

  double _kbAxis = 0;
  bool _loaded = false;
  bool inventoryOpen = false;
  bool _btnJumpHeld = false;
  bool _paused = false;
  double _playtimeSeconds = 0;
  String? _currentSaveId;

  // Auto-save
  double _autoSaveTimer = 0;
  static const double autoSaveInterval = 120.0;
  static const double playerAttackCooldown = 0.28;
  double _playerAttackCooldownTimer = 0;

  // Hold-to-mine state
  bool _btnMineHeld = false; // mobile mine button held
  bool _tapMineHeld = false; // left-click held on a tile
  int _tapMineTx = 0;
  int _tapMineTy = 0;

  // Active mining target (for HP reset on stop/change)
  int _activeMiningTx = -1;
  int _activeMiningTy = -1;

  // Teleport doors
  final List<TeleportDoor> doors = [];
  int _nextDoorId = 1;
  TeleportDoor? interactingDoor;
  DungeonPortal? interactingPortal;

  // Dungeon Persistence
  List<Map<String, dynamic>>? _savedOverworldTiles;
  Vector2? _savedPlayerPos;
  List<Map<String, dynamic>>? _savedDungeonTiles;
  Vector2? _savedDungeonPlayerPos;
  DungeonFlowState _dungeonFlowState = DungeonFlowState.surface;
  DungeonRunResult? _lastDungeonResult;
  final Random _rng = Random();
  double _runElapsedSeconds = 0;
  int _lastObservedHp = 0;

  static Vector2 get _surfacePortalPos =>
      Vector2(300, (skyRows - 2) * tileSize.toDouble());

  bool get _showTouchControls =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  MiningGame({this.initialSaveData});

  Inventory get inventory => gameState.inventory;
  bool get isPaused => _paused;
  DungeonRunResult? get lastDungeonResult => _lastDungeonResult;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    HardwareKeyboard.instance.addHandler(_handleKey);

    await images.loadAll([
      'tiles/grass.png',
      'tiles/dirt.png',
      'tiles/stone.png',
      'tiles/copper.png',
      'tiles/iron.png',
      'tiles/gold.png',
      'tiles/diamond.png',
      'tiles/bedrock.png',
      'tiles/crack_1.png',
      'tiles/crack_2.png',
      'tiles/crack_3.png',
      'tiles/crack_4.png',
      'player/Sprite-0001-sheet.png',
      'objects/tnt.png',
      'objects/portal_0.png',
      'objects/portal_1.png',
      'objects/portal_2.png',
      'objects/portal_3.png',
      'objects/explosion_0.png',
      'objects/explosion_1.png',
      'objects/explosion_2.png',
      'objects/explosion_3.png',
      'backgrounds/sky.png',
      'backgrounds/underground_1.png',
      'backgrounds/underground_2.png',
      'backgrounds/underground_3.png',
      'player/gear_pickaxe.png',
      'player/gear_drill.png',
      'player/gear_jetpack.png',
      'player/gear_sword.png',
      'monsters/1 Pink_Monster/Pink_Monster_Idle_4.png',
      'monsters/1 Pink_Monster/Pink_Monster_Walk_6.png',
      'monsters/1 Pink_Monster/Pink_Monster_Jump_8.png',
      'monsters/1 Pink_Monster/Pink_Monster_Attack1_4.png',
      'monsters/1 Pink_Monster/Pink_Monster_Hurt_4.png',
      'monsters/1 Pink_Monster/Pink_Monster_Death_8.png',
      'monsters/2 Owlet_Monster/Owlet_Monster_Idle_4.png',
      'monsters/2 Owlet_Monster/Owlet_Monster_Walk_6.png',
      'monsters/2 Owlet_Monster/Owlet_Monster_Jump_8.png',
      'monsters/2 Owlet_Monster/Owlet_Monster_Attack1_4.png',
      'monsters/2 Owlet_Monster/Owlet_Monster_Hurt_4.png',
      'monsters/2 Owlet_Monster/Owlet_Monster_Death_8.png',
      'monsters/3 Dude_Monster/Dude_Monster_Idle_4.png',
      'monsters/3 Dude_Monster/Dude_Monster_Walk_6.png',
      'monsters/3 Dude_Monster/Dude_Monster_Jump_8.png',
      'monsters/3 Dude_Monster/Dude_Monster_Attack1_4.png',
      'monsters/3 Dude_Monster/Dude_Monster_Hurt_4.png',
      'monsters/3 Dude_Monster/Dude_Monster_Death_8.png',
      // UI Icons
      'items/block_gold.png',
      'items/fuel.png',
      'items/block_bedrock.png',
      'items/pickaxe_wood.png',
      'items/pickaxe_stone.png',
      'items/pickaxe_iron.png',
      'items/pickaxe_gold.png',
      'items/pickaxe_diamond.png',
      'items/drill_mk1.png',
      'items/drill_mk2.png',
      'items/drill_mk3.png',
    ]);

    final tileSprites = <TileType, Sprite>{
      TileType.grass: Sprite(images.fromCache('tiles/grass.png')),
      TileType.dirt: Sprite(images.fromCache('tiles/dirt.png')),
      TileType.stone: Sprite(images.fromCache('tiles/stone.png')),
      TileType.copper: Sprite(images.fromCache('tiles/copper.png')),
      TileType.iron: Sprite(images.fromCache('tiles/iron.png')),
      TileType.gold: Sprite(images.fromCache('tiles/gold.png')),
      TileType.diamond: Sprite(images.fromCache('tiles/diamond.png')),
      TileType.bedrock: Sprite(images.fromCache('tiles/bedrock.png')),
    };

    TileComponent.configure(
      tileSprites: tileSprites,
      crackSprites: [
        Sprite(images.fromCache('tiles/crack_1.png')),
        Sprite(images.fromCache('tiles/crack_2.png')),
        Sprite(images.fromCache('tiles/crack_3.png')),
        Sprite(images.fromCache('tiles/crack_4.png')),
      ],
    );

    final playerSheet = images.fromCache('player/Sprite-0001-sheet.png');
    _playerRight = Sprite(
      playerSheet,
      srcPosition: Vector2(0, 0),
      srcSize: Vector2(24, 24),
    );
    _playerFront = Sprite(
      playerSheet,
      srcPosition: Vector2(26, 0),
      srcSize: Vector2(24, 24),
    );
    _playerUpRight = Sprite(
      playerSheet,
      srcPosition: Vector2(52, 0),
      srcSize: Vector2(24, 24),
    );
    _playerUp = Sprite(
      playerSheet,
      srcPosition: Vector2(78, 0),
      srcSize: Vector2(24, 24),
    );
    final gearPickaxe = Sprite(images.fromCache('player/gear_pickaxe.png'));
    final gearDrill = Sprite(images.fromCache('player/gear_drill.png'));
    final gearJetpack = Sprite(images.fromCache('player/gear_jetpack.png'));
    final gearSword = Sprite(images.fromCache('player/gear_sword.png'));
    _tntSprite = Sprite(images.fromCache('objects/tnt.png'));
    _portalFrames = [
      Sprite(images.fromCache('objects/portal_0.png')),
      Sprite(images.fromCache('objects/portal_1.png')),
      Sprite(images.fromCache('objects/portal_2.png')),
      Sprite(images.fromCache('objects/portal_3.png')),
    ];
    _explosionFrames = [
      Sprite(images.fromCache('objects/explosion_0.png')),
      Sprite(images.fromCache('objects/explosion_1.png')),
      Sprite(images.fromCache('objects/explosion_2.png')),
      Sprite(images.fromCache('objects/explosion_3.png')),
    ];
    _monsterAnimations = _buildMonsterAnimations();

    gameWorld = World();
    gameCamera = CameraComponent.withFixedResolution(
      world: gameWorld,
      width: 640,
      height: 360,
    );
    addAll([gameWorld, gameCamera]);

    // Sky background
    gameWorld.add(
      SpriteComponent(
        sprite: Sprite(images.fromCache('backgrounds/sky.png')),
        position: Vector2.zero(),
        size: Vector2(worldWidth * tileSize, skyRows * tileSize),
        priority: -1,
      ),
    );

    // Underground backgrounds (3 depth zones)
    const zone1Rows = 65; // shallow: rows 5–69
    const zone2Rows = 65; // medium:  rows 70–134
    final zone3Rows =
        worldHeight - skyRows - zone1Rows - zone2Rows; // deep: rest
    final bgZones = <(String, int, int)>[
      ('backgrounds/underground_1.png', skyRows, zone1Rows),
      ('backgrounds/underground_2.png', skyRows + zone1Rows, zone2Rows),
      (
        'backgrounds/underground_3.png',
        skyRows + zone1Rows + zone2Rows,
        zone3Rows,
      ),
    ];
    for (final (path, startRow, rows) in bgZones) {
      gameWorld.add(
        SpriteComponent(
          sprite: Sprite(images.fromCache(path)),
          position: Vector2(0, startRow * tileSize),
          size: Vector2(worldWidth * tileSize, rows * tileSize),
          priority: -2,
        ),
      );
    }

    // World
    worldManager = WorldManager(world: gameWorld);
    if (initialSaveData != null) {
      worldManager.loadFromJson(initialSaveData!.tiles);
    } else {
      worldManager.generate();
    }

    // Player
    final startPos = initialSaveData != null
        ? Vector2(initialSaveData!.playerX, initialSaveData!.playerY)
        : Vector2(
            worldWidth * tileSize / 2,
            (skyRows - 2) * tileSize.toDouble(),
          );
    player = PlayerComponent(
      position: startPos,
      spriteRight: _playerRight,
      spriteFront: _playerFront,
      spriteUpRight: _playerUpRight,
      spriteUp: _playerUp,
      gearPickaxe: gearPickaxe,
      gearDrill: gearDrill,
      gearJetpack: gearJetpack,
      gearSword: gearSword,
    );
    gameWorld.add(player);

    // Restore save data
    if (initialSaveData != null) {
      final sd = initialSaveData!;
      player.velocity
        ..x = sd.velocityX
        ..y = sd.velocityY;
      gameState.loadFromJson({
        'hp': sd.hp,
        'maxHp': sd.maxHp,
        'gold': sd.gold,
        'pickaxeTier': sd.pickaxeTier,
        'level': sd.level,
        'xp': sd.xp,
        'dungeonTokens': sd.dungeonTokens,
        'combatDamageBonusLevel': sd.combatDamageBonusLevel,
        'dungeonShieldCharges': sd.dungeonShieldCharges,
        'hasJetpack': sd.hasJetpack,
        'jetpackFuel': sd.jetpackFuel,
        'jetpackMaxFuel': sd.jetpackMaxFuel,
        'worldMode': sd.worldMode,
      });
      gameState.inventory.loadFromJson(sd.inventorySlots);
      gameState.inventory.select(sd.selectedHotbar);
      _playtimeSeconds = sd.playtimeSeconds.toDouble();
      _currentSaveId = sd.id;
      if (sd.lastDungeonType != null) {
        final dt = DungeonType.values.firstWhere(
          (t) => t.name == sd.lastDungeonType,
          orElse: () => DungeonType.cavern,
        );
        _lastDungeonResult = DungeonRunResult(
          type: dt,
          cleared: false,
          reachedWave: sd.lastClearedWave ?? 0,
          earnedTokens: 0,
          lostTokens: 0,
          finalTokens: 0,
        );
      }
      if (gameState.inDungeon && sd.activeDungeonType != null) {
        final dt = DungeonType.values.firstWhere(
          (t) => t.name == sd.activeDungeonType,
          orElse: () => DungeonType.cavern,
        );
        final run = DungeonRunState(
          type: dt,
          totalWaves: dungeonTypeSpecs[dt]!.totalWaves,
        );
        run.currentWave = sd.activeDungeonWave ?? 1;
        run.runTokenEarned = sd.activeDungeonRunToken ?? 0;
        run.runDamageTaken = sd.activeDungeonRunDamage ?? 0;
        run.waveStartDamageTaken = run.runDamageTaken;
        run.waveStartTime = sd.activeDungeonElapsed ?? 0;
        gameState.activeDungeonRun = run;
        _runElapsedSeconds = sd.activeDungeonElapsed ?? 0;
      }
      _savedOverworldTiles = sd.overworldSnapshot;
      _savedDungeonTiles = sd.dungeonSnapshot;
      if (sd.overworldPlayerX != null && sd.overworldPlayerY != null) {
        _savedPlayerPos = Vector2(sd.overworldPlayerX!, sd.overworldPlayerY!);
      }
      if (sd.dungeonPlayerX != null && sd.dungeonPlayerY != null) {
        _savedDungeonPlayerPos = Vector2(
          sd.dungeonPlayerX!,
          sd.dungeonPlayerY!,
        );
      }
      _dungeonFlowState = gameState.inDungeon
          ? DungeonFlowState.activeWave
          : DungeonFlowState.surface;
      if (gameState.inDungeon && gameState.activeDungeonRun == null) {
        final fallback = DungeonType.cavern;
        gameState.activeDungeonRun = DungeonRunState(
          type: fallback,
          totalWaves: dungeonTypeSpecs[fallback]!.totalWaves,
        )..currentWave = 1;
      }
      if (gameState.inDungeon && _savedOverworldTiles == null) {
        final activeDungeonTiles = worldManager.tilesToJson();
        worldManager.generate();
        _savedOverworldTiles = worldManager.tilesToJson();
        worldManager.loadFromJson(activeDungeonTiles);
        _savedPlayerPos =
            _savedPlayerPos ??
            Vector2(
              worldWidth * tileSize / 2,
              (skyRows - 2) * tileSize.toDouble(),
            );
      }

      // Restore teleport doors
      for (final doorData in sd.doors) {
        final door = TeleportDoor(
          position: Vector2(
            (doorData['x'] as num).toDouble(),
            (doorData['y'] as num).toDouble(),
          ),
          id: doorData['id'] as int,
          animation: _buildPortalAnimation(),
        );
        doors.add(door);
        if (!gameState.inDungeon) {
          gameWorld.add(door);
        }
      }
      if (doors.isNotEmpty) {
        _nextDoorId =
            doors.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1;
      }
    }

    // Facing outline indicator
    _facingOutline = _FacingOutline();
    gameWorld.add(_facingOutline);

    // Smooth camera target – follows player with lerp, camera follows this
    _cameraTarget = _CameraTarget(player: player);
    _cameraTarget.position = player.position.clone();
    gameWorld.add(_cameraTarget);
    gameCamera.follow(_cameraTarget, snap: true);
    gameCamera.setBounds(
      Rectangle.fromLTWH(0, 0, worldWidth * tileSize, worldHeight * tileSize),
    );

    if (initialSaveData == null) {
      _ensureSurfacePortal();
    } else if (!gameState.inDungeon) {
      _ensureSurfacePortal();
    } else {
      _removeAllSurfaceEntities();
      gameWorld.children.whereType<DungeonPortal>().forEach(
        (p) => p.removeFromParent(),
      );
    }

    // ── Controls ───────────────────────────────────────────────────────────
    final hud = HudComponent();
    _hud = hud;

    if (_showTouchControls) {
      final joystick = JoystickComponent(
        knob: CircleComponent(
          radius: 20,
          paint: Paint()..color = const Color(0xBBFFFFFF),
        ),
        background: CircleComponent(
          radius: 44,
          paint: Paint()..color = const Color(0x55FFFFFF),
        ),
        margin: const EdgeInsets.only(left: 20, bottom: 20),
      );
      _joystick = joystick;

      final jumpBtn = HudButtonComponent(
        button: CircleComponent(
          radius: 26,
          paint: Paint()..color = const Color(0xAAFFD166),
        ),
        buttonDown: CircleComponent(
          radius: 26,
          paint: Paint()..color = const Color(0xFFFFB703),
        ),
        margin: const EdgeInsets.only(right: 20, bottom: 28),
        onPressed: () => _btnJumpHeld = true,
        onReleased: () => _btnJumpHeld = false,
      );

      final mineBtn = HudButtonComponent(
        button: CircleComponent(
          radius: 22,
          paint: Paint()..color = const Color(0xAAFF6B6B),
        ),
        buttonDown: CircleComponent(
          radius: 22,
          paint: Paint()..color = const Color(0xFFFF4444),
        ),
        margin: const EdgeInsets.only(right: 80, bottom: 34),
        onPressed: () => _btnMineHeld = true,
        onReleased: () => _btnMineHeld = false,
      );

      final placeBtn = HudButtonComponent(
        button: CircleComponent(
          radius: 22,
          paint: Paint()..color = const Color(0xAA6BCB77),
        ),
        buttonDown: CircleComponent(
          radius: 22,
          paint: Paint()..color = const Color(0xFF4CAF50),
        ),
        margin: const EdgeInsets.only(right: 140, bottom: 34),
        onPressed: _placeFacing,
      );

      gameCamera.viewport.addAll([joystick, jumpBtn, mineBtn, placeBtn, hud]);
    } else {
      _joystick = null;
      gameCamera.viewport.add(hud);
    }
    _lastObservedHp = gameState.hp;
    _loaded = true;
  }

  @override
  void onRemove() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.onRemove();
  }

  // ── Update ───────────────────────────────────────────────────────────────

  void pauseGame() {
    _paused = true;
  }

  void resumeGame() {
    _paused = false;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_loaded || _paused) return;

    _playtimeSeconds += dt;
    final hpDrop = _lastObservedHp - gameState.hp;
    if (hpDrop > 0) {
      player.triggerDamageFlash();
    }
    if (gameState.activeDungeonRun != null) {
      _runElapsedSeconds += dt;
      if (hpDrop > 0) {
        gameState.activeDungeonRun!.onDamageTaken(hpDrop);
      }
    }
    _lastObservedHp = gameState.hp;
    if (_playerAttackCooldownTimer > 0) {
      _playerAttackCooldownTimer =
          (_playerAttackCooldownTimer - dt).clamp(0.0, playerAttackCooldown);
    }

    // Auto-save
    _autoSaveTimer += dt;
    if (_autoSaveTimer >= autoSaveInterval) {
      _autoSaveTimer = 0;
      _autoSave();
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;

    // ── Movement & facing ─────────────────────────────────────────────────
    if (!inventoryOpen) {
      final joystickDelta = _joystick?.relativeDelta ?? Vector2.zero();
      final jx = joystickDelta.x.clamp(-1.0, 1.0);
      final jy = joystickDelta.y.clamp(-1.0, 1.0);
      player.setMoveInput(jx.abs() > 0.1 ? jx : _kbAxis);

      // Joystick → set facing (including diagonals)
      final jUp = jy < -0.3;
      final jDown = jy > 0.3;
      if (jUp && jx < -0.3) {
        player.facingDir = FacingDir.upLeft;
      } else if (jUp && jx > 0.3) {
        player.facingDir = FacingDir.upRight;
      } else if (jDown && jx < -0.3) {
        player.facingDir = FacingDir.downLeft;
      } else if (jDown && jx > 0.3) {
        player.facingDir = FacingDir.downRight;
      } else if (jUp) {
        player.facingDir = FacingDir.up;
      } else if (jDown) {
        player.facingDir = FacingDir.down;
      }

      // Keyboard facing (overrides joystick if pressed)
      final kbUp =
          pressed.contains(LogicalKeyboardKey.keyW) ||
          pressed.contains(LogicalKeyboardKey.arrowUp);
      final kbDown =
          pressed.contains(LogicalKeyboardKey.keyS) ||
          pressed.contains(LogicalKeyboardKey.arrowDown);
      final kbLeft =
          pressed.contains(LogicalKeyboardKey.keyA) ||
          pressed.contains(LogicalKeyboardKey.arrowLeft);
      final kbRight =
          pressed.contains(LogicalKeyboardKey.keyD) ||
          pressed.contains(LogicalKeyboardKey.arrowRight);

      // Diagonal combinations
      if (kbUp && kbLeft) {
        player.facingDir = FacingDir.upLeft;
      } else if (kbUp && kbRight) {
        player.facingDir = FacingDir.upRight;
      } else if (kbDown && kbLeft) {
        player.facingDir = FacingDir.downLeft;
      } else if (kbDown && kbRight) {
        player.facingDir = FacingDir.downRight;
      } else if (kbUp) {
        player.facingDir = FacingDir.up;
      } else if (kbDown) {
        player.facingDir = FacingDir.down;
      }
    } else {
      player.setMoveInput(0);
    }

    // Jump held = keyboard OR mobile button
    final kbJump = !inventoryOpen && pressed.contains(LogicalKeyboardKey.space);
    player.jumpHeld = kbJump || _btnJumpHeld;

    // ── Continuous mining OR Combat (mine button / left-click only) ─────────────────
    int curMineTx = -1, curMineTy = -1;
    final isCombat = gameState.isCombatMode;

    if (_tapMineHeld) {
      // Left-click hold takes priority
      if (isCombat) {
        _tryAttack(dt, _tapMineTx, _tapMineTy);
      } else {
        if (worldManager.hasTileAt(_tapMineTx, _tapMineTy)) {
          curMineTx = _tapMineTx;
          curMineTy = _tapMineTy;
          _tryMineDps(_tapMineTx, _tapMineTy, dt);
        } else {
          _tapMineHeld = false;
        }
      }
    } else if (!inventoryOpen &&
        (_btnMineHeld ||
            pressed.contains(LogicalKeyboardKey.shiftLeft) ||
            pressed.contains(LogicalKeyboardKey.shiftRight))) {
      if (isCombat) {
        _tryAttack(dt, -1, -1); // Auto-target facing
      } else {
        final (tx, ty) = _facingTile();
        curMineTx = tx;
        curMineTy = ty;
        _tryMineDps(tx, ty, dt);
      }
    }

    // Reset partially-mined tile when target changes or mining stops
    if (_activeMiningTx != curMineTx || _activeMiningTy != curMineTy) {
      if (_activeMiningTx >= 0) {
        worldManager.resetTileHp(_activeMiningTx, _activeMiningTy);
      }
    }
    _activeMiningTx = curMineTx;
    _activeMiningTy = curMineTy;

    // Communicate mining state to player for gear overlay rendering
    player.isMining = (_activeMiningTx >= 0);
    player.miningTier = gameState.pickaxeTier;

    // ── Facing outline indicator ─────────────────────────────────────────
    _updateFacingOutline();

    // ── World / HUD ──────────────────────────────────────────────────────
    worldManager.updateVisibleTiles(
      gameCamera.viewfinder.position,
      Vector2(640, 360),
    );

    _hud?.updateFrom(gameState, player.depth);

    if (gameState.isDead && !overlays.isActive('death')) {
      final wasDungeonDeath = gameState.inDungeon;
      if (wasDungeonDeath) {
        _handleDungeonDeathRecovery();
      }
      gameState.die(keepInventory: wasDungeonDeath);
      if (!gameState.inDungeon) {
        if (_savedPlayerPos != null) {
          player.position = _savedPlayerPos!.clone();
        } else {
          player.respawnAtSurface();
        }
      }
      if (!wasDungeonDeath) {
        overlays.add('death');
      }
    }

    _checkDungeonClear();
  }

  void _checkDungeonClear() {
    if (_dungeonFlowState != DungeonFlowState.activeWave) return;
    if (!gameState.inDungeon) return;
    final run = gameState.activeDungeonRun;
    if (run == null) return;
    final spec = dungeonTypeSpecs[run.type]!;

    final monsters = gameWorld.children.whereType<MonsterComponent>().toList();
    if (monsters.isNotEmpty) return;

    _dungeonFlowState = DungeonFlowState.betweenWaves;
    run.completeWave(spec: spec, currentRunTimeSeconds: _runElapsedSeconds);

    if (!run.isCleared) {
      _startNextWave();
      return;
    }

    final result = run.finalizeRun();
    gameState.dungeonTokens += result.finalTokens;
    _lastDungeonResult = result;
    gameState.activeDungeonRun = null;
    _dungeonFlowState = DungeonFlowState.cleared;

    // Spawn exit portal once all waves are cleared.
    final exitX =
        (spec.config.startX + (spec.config.roomWidth ~/ 2) + 1) *
        tileSize.toDouble();
    final exitY =
        (spec.config.startY + (spec.config.roomHeight ~/ 2) + 1) *
        tileSize.toDouble();
    final portals = gameWorld.children.whereType<DungeonPortal>();
    final hasExit = portals.any((p) => p.isExit);
    if (!hasExit) {
      gameWorld.add(
        DungeonPortal(
          position: Vector2(exitX, exitY),
          animation: SpriteAnimation.spriteList(_portalFrames, stepTime: 0.1),
          isExit: true,
        ),
      );
    }
    overlays.add('dungeon_result');
  }

  void _updateFacingOutline() {
    // If tap-mining a specific tile, show outline there instead of facing tile
    final int otx, oty;
    if (_tapMineHeld && worldManager.hasTileAt(_tapMineTx, _tapMineTy)) {
      otx = _tapMineTx;
      oty = _tapMineTy;
    } else {
      final (ftx, fty) = _facingTile();
      otx = ftx;
      oty = fty;
    }

    if (worldManager.hasTileAt(otx, oty)) {
      _facingOutline.position
        ..x = otx * tileSize
        ..y = oty * tileSize;
      _facingOutline.visible = true;

      // Mining progress: show green outline proportional to damage dealt
      if (_activeMiningTx == otx && _activeMiningTy == oty) {
        final state = worldManager.tiles[oty][otx]!;
        final maxHp = tileSpecs[state.type]!.maxHp.toDouble();
        _facingOutline.miningProgress = 1.0 - (state.hp / maxHp);
      } else {
        _facingOutline.miningProgress = 0;
      }
    } else {
      _facingOutline.visible = false;
      _facingOutline.miningProgress = 0;
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────

  SaveData exportSaveData() {
    final depth = ((player.position.y / tileSize) - skyRows).round();
    return SaveData(
      id: _currentSaveId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Depth $depth - ${gameState.gold}G',
      timestamp: DateTime.now(),
      playtimeSeconds: _playtimeSeconds.round(),
      playerX: player.position.x,
      playerY: player.position.y,
      velocityX: player.velocity.x,
      velocityY: player.velocity.y,
      worldMode: gameState.worldMode.name,
      hp: gameState.hp,
      maxHp: gameState.maxHp,
      gold: gameState.gold,
      level: gameState.level,
      xp: gameState.xp,
      dungeonTokens: gameState.dungeonTokens,
      combatDamageBonusLevel: gameState.combatDamageBonusLevel,
      dungeonShieldCharges: gameState.dungeonShieldCharges,
      pickaxeTier: gameState.pickaxeTier.name,
      hasJetpack: gameState.hasJetpack,
      jetpackFuel: gameState.jetpackFuel,
      jetpackMaxFuel: gameState.jetpackMaxFuel,
      inventorySlots: gameState.inventory.toJson(),
      selectedHotbar: gameState.inventory.selected,
      tiles: worldManager.tilesToJson(),
      overworldSnapshot: gameState.inDungeon
          ? _savedOverworldTiles
          : worldManager.tilesToJson(),
      dungeonSnapshot: gameState.inDungeon
          ? worldManager.tilesToJson()
          : _savedDungeonTiles,
      overworldPlayerX: gameState.inDungeon
          ? _savedPlayerPos?.x
          : player.position.x,
      overworldPlayerY: gameState.inDungeon
          ? _savedPlayerPos?.y
          : player.position.y,
      dungeonPlayerX: gameState.inDungeon
          ? player.position.x
          : _savedDungeonPlayerPos?.x,
      dungeonPlayerY: gameState.inDungeon
          ? player.position.y
          : _savedDungeonPlayerPos?.y,
      lastDungeonType: _lastDungeonResult?.type.name,
      lastClearedWave: _lastDungeonResult?.reachedWave,
      activeDungeonType: gameState.activeDungeonRun?.type.name,
      activeDungeonWave: gameState.activeDungeonRun?.currentWave,
      activeDungeonRunToken: gameState.activeDungeonRun?.runTokenEarned,
      activeDungeonRunDamage: gameState.activeDungeonRun?.runDamageTaken,
      activeDungeonElapsed: gameState.activeDungeonRun != null
          ? _runElapsedSeconds
          : null,
      doors: doors
          .map(
            (d) => <String, dynamic>{
              'id': d.id,
              'x': d.position.x,
              'y': d.position.y,
            },
          )
          .toList(),
    );
  }

  Future<void> saveGame() async {
    final data = exportSaveData();
    _currentSaveId ??= data.id;
    await SaveManager().save(data);
  }

  Future<void> _autoSave() async {
    await saveGame();
  }

  // ── Left click → mine ─────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (!_loaded || inventoryOpen || _paused) return;
    final wp = gameCamera.globalToLocal(event.canvasPosition);
    final tx = (wp.x / tileSize).floor();
    final ty = (wp.y / tileSize).floor();

    if (worldManager.hasTileAt(tx, ty)) {
      // Left click on block → hold-to-mine
      _tapMineHeld = true;
      _tapMineTx = tx;
      _tapMineTy = ty;
    } else {
      // Check Dungeon Portal
      final portals = gameWorld.children.whereType<DungeonPortal>();
      for (final p in portals) {
        if (p.toRect().contains(wp.toOffset())) {
          _openDungeonPortalConfirm(p);
          return;
        }
      }

      // Left click on empty → interact with teleport door
      final door = _doorAt(tx, ty);
      if (door != null) {
        interactingDoor = door;
        overlays.add('teleport');
      }
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    _tapMineHeld = false;
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    _tapMineHeld = false;
  }

  // ── Right click → place (called from main.dart Listener) ──────────────

  void handleRightClickDown(Offset screenPos) {
    if (!_loaded || inventoryOpen || _paused) return;
    final wp = gameCamera.globalToLocal(Vector2(screenPos.dx, screenPos.dy));
    final tx = (wp.x / tileSize).floor();
    final ty = (wp.y / tileSize).floor();

    if (worldManager.hasTileAt(tx, ty)) {
      // Right click on block → place adjacent on cursor side
      _placeAdjacentToBlock(tx, ty, wp);
    } else {
      // Check Dungeon Portal
      final portals = gameWorld.children.whereType<DungeonPortal>();
      for (final p in portals) {
        if (p.toRect().contains(wp.toOffset())) {
          _openDungeonPortalConfirm(p);
          return;
        }
      }

      // Right click on empty → place or interact with door
      final door = _doorAt(tx, ty);
      if (door != null) {
        interactingDoor = door;
        overlays.add('teleport');
        return;
      }
      _tryUseOrPlace(tx, ty);
    }
  }

  // ── Mining helpers ────────────────────────────────────────────────────

  /// Get the tile coordinates the player is facing.
  (int, int) _facingTile() {
    final px = ((player.position.x + player.size.x / 2) / tileSize).floor();
    final centerY = ((player.position.y + player.size.y / 2) / tileSize)
        .floor();
    final belowY = ((player.position.y + player.size.y) / tileSize).floor();
    switch (player.facingDir) {
      case FacingDir.left:
        return (px - 1, centerY);
      case FacingDir.right:
        return (px + 1, centerY);
      case FacingDir.up:
        return (px, centerY - 1);
      case FacingDir.down:
        return (px, belowY);
      case FacingDir.upLeft:
        return (px - 1, centerY - 1);
      case FacingDir.upRight:
        return (px + 1, centerY - 1);
      case FacingDir.downLeft:
        return (px - 1, belowY);
      case FacingDir.downRight:
        return (px + 1, belowY);
    }
  }

  /// Apply DPS-based damage to a tile. miningDamage = damage per second.
  bool _tryMineDps(int x, int y, double dt) {
    if (x < 0 || y < 0 || x >= worldWidth || y >= worldHeight) return false;
    final tc = Vector2((x + 0.5) * tileSize, (y + 0.5) * tileSize);
    if (tc.distanceTo(player.center) > player.reach) return false;

    final dps = gameState.miningDamage.toDouble();
    final damage = dps * dt;

    final tileType = worldManager.mine(x, y, damage);
    if (tileType != null) {
      final item = tileDropItem(tileType);
      if (item != null) inventory.addItem(item);
      final oreXp = oreXpForTile(tileType);
      if (oreXp > 0) gameState.addXp(oreXp);
      return true;
    }
    return worldManager.hasTileAt(x, y);
  }

  void _tryAttack(double dt, int tx, int ty) {
    if (_playerAttackCooldownTimer > 0) return;
    _playerAttackCooldownTimer = playerAttackCooldown;

    // Visual attack cue
    player.triggerAttackSwing();

    // Target area
    Rect attackRect;
    if (tx >= 0 && ty >= 0) {
      attackRect = Rect.fromLTWH(
        tx * tileSize,
        ty * tileSize,
        tileSize,
        tileSize,
      );
    } else {
      final (ftx, fty) = _facingTile();
      attackRect = Rect.fromLTWH(
        ftx * tileSize,
        fty * tileSize,
        tileSize,
        tileSize,
      );
    }
    gameWorld.add(
      AttackRangeEffectComponent(
        center: Vector2(attackRect.center.dx, attackRect.center.dy),
        radius: tileSize * 0.75,
        color: const Color(0xFFFFE082),
      ),
    );

    // Check overlap with monsters
    final monsters = worldManager.world.children.whereType<MonsterComponent>();
    final attackDamage = (10 * gameState.combatDamageMultiplier).round().clamp(
      1,
      9999,
    );
    for (final m in monsters) {
      if (m.toRect().overlaps(attackRect)) {
        m.takeDamage(attackDamage);
        // Simple knockback
        if (m.position != player.position) {
          final dir = (m.position - player.position).normalized();
          m.position += dir * 20;
        }
      }
    }
  }

  List<DungeonTypeSpec> availableDungeonTypes() {
    return DungeonType.values.map((t) => dungeonTypeSpecs[t]!).toList();
  }

  void startSelectedDungeon(DungeonType type) {
    overlays.remove('dungeon_select');
    interactingPortal = null;
    final spec = dungeonTypeSpecs[type]!;
    if (gameState.level < spec.unlockLevel) {
      return;
    }
    _startDungeonRun(type);
  }

  void cancelDungeonSelection() {
    overlays.remove('dungeon_select');
    interactingPortal = null;
    _dungeonFlowState = DungeonFlowState.surface;
  }

  void confirmDungeonAction() {
    if (interactingPortal == null) return;

    if (interactingPortal!.isExit) {
      _returnToSurface();
      interactingPortal = null;
      return;
    }

    overlays.add('dungeon_select');
    _dungeonFlowState = DungeonFlowState.selectingType;
  }

  void cancelDungeonAction() {
    interactingPortal = null;
    _dungeonFlowState = DungeonFlowState.surface;
  }

  void _startDungeonRun(DungeonType type) {
    if (gameState.inDungeon) return;
    if (_dungeonFlowState == DungeonFlowState.entering ||
        _dungeonFlowState == DungeonFlowState.escaping) {
      return;
    }

    final spec = dungeonTypeSpecs[type]!;
    _dungeonFlowState = DungeonFlowState.entering;

    _savedOverworldTiles = worldManager.tilesToJson();
    _savedPlayerPos = player.position.clone();
    _savedDungeonTiles = null;
    _savedDungeonPlayerPos = null;

    if (gameState.dungeonShieldCharges > 0) {
      gameState.dungeonShieldCharges -= 1;
      gameState.activeShieldHits = 1;
    } else {
      gameState.activeShieldHits = 0;
    }

    gameState.worldMode = WorldMode.dungeon;
    _runElapsedSeconds = 0;
    gameState.activeDungeonRun = DungeonRunState(
      type: type,
      totalWaves: spec.totalWaves,
    );

    _removeAllSurfaceEntities();
    _removeAllDungeonEntities();
    gameWorld.children.whereType<MonsterComponent>().forEach((m) {
      m.removeFromParent();
    });

    worldManager.generateDungeon(spec.config);
    _savedDungeonTiles = worldManager.tilesToJson();

    final spawnX =
        (spec.config.startX + (spec.config.roomWidth ~/ 2) + 1) *
        tileSize.toDouble();
    final spawnY =
        (spec.config.startY + (spec.config.roomHeight ~/ 2) + 1) *
        tileSize.toDouble();
    player.position = Vector2(spawnX, spawnY);
    player.velocity.setZero();
    _savedDungeonPlayerPos = player.position.clone();

    _startNextWave();
  }

  void _startNextWave() {
    final run = gameState.activeDungeonRun;
    if (run == null) return;
    final spec = dungeonTypeSpecs[run.type]!;

    gameWorld.children.whereType<MonsterComponent>().forEach((m) {
      m.removeFromParent();
    });
    run.startWave(_runElapsedSeconds);
    _dungeonFlowState = DungeonFlowState.activeWave;
    _spawnWaveMonsters(spec, run.currentWave);
  }

  void _spawnWaveMonsters(DungeonTypeSpec spec, int wave) {
    final count = spec.spawnCountForWave(wave);
    final roomLeft = (spec.config.startX + 2) * tileSize.toDouble();
    final roomRight =
        (spec.config.startX + spec.config.roomWidth) * tileSize.toDouble();
    final roomGroundY =
        (spec.config.startY + spec.config.roomHeight) * tileSize.toDouble();

    final monsters = <MonsterComponent>[];
    for (var i = 0; i < count; i++) {
      final kind = _pickMonsterKind(spec.monsterWeights);
      final x = roomLeft + _rng.nextDouble() * (roomRight - roomLeft);
      final y = roomGroundY - tileSize * (1.2 + _rng.nextDouble() * 0.5);
      monsters.add(
        MonsterComponent(
          position: Vector2(x, y),
          kind: kind,
          animations: _monsterAnimations[kind]!,
          onDeath: _onDungeonMonsterDeath,
        ),
      );
    }
    gameWorld.addAll(monsters);
  }

  MonsterKind _pickMonsterKind(Map<MonsterKind, double> weights) {
    final total = weights.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return MonsterKind.pink;
    var roll = _rng.nextDouble() * total;
    for (final e in weights.entries) {
      roll -= e.value;
      if (roll <= 0) return e.key;
    }
    return MonsterKind.pink;
  }

  void _onDungeonMonsterDeath(MonsterComponent _) {
    // Wave clear is detected in update loop.
  }

  void _returnToSurface() {
    if (_dungeonFlowState == DungeonFlowState.escaping) return;
    if (!gameState.inDungeon) return;
    _dungeonFlowState = DungeonFlowState.escaping;
    gameState.worldMode = WorldMode.overworld;

    _savedDungeonTiles = worldManager.tilesToJson();
    _savedDungeonPlayerPos = player.position.clone();
    _removeAllDungeonEntities();
    gameWorld.children.whereType<MonsterComponent>().forEach((m) {
      m.removeFromParent();
    });

    if (_savedOverworldTiles != null) {
      worldManager.loadFromJson(_savedOverworldTiles!);
      if (_savedPlayerPos != null) {
        player.position = _savedPlayerPos!;
      } else {
        player.respawnAtSurface();
      }
    } else {
      worldManager.generate();
      player.respawnAtSurface();
    }
    player.velocity.setZero();
    gameState.activeShieldHits = 0;
    gameState.activeDungeonRun = null;
    _runElapsedSeconds = 0;

    _restoreSurfaceEntities();
    _dungeonFlowState = DungeonFlowState.surface;
  }

  // ── Placement ─────────────────────────────────────────────────────────

  /// Check if at least one adjacent tile is solid.
  bool _hasAdjacentBlock(int x, int y) {
    return worldManager.hasTileAt(x - 1, y) ||
        worldManager.hasTileAt(x + 1, y) ||
        worldManager.hasTileAt(x, y - 1) ||
        worldManager.hasTileAt(x, y + 1);
  }

  /// Place item adjacent to clicked block (tx,ty) on the side closest
  /// to the world-space cursor position [wp].
  bool _placeAdjacentToBlock(int tx, int ty, Vector2 wp) {
    final cx = (tx + 0.5) * tileSize;
    final cy = (ty + 0.5) * tileSize;
    final dx = wp.x - cx;
    final dy = wp.y - cy;

    int px, py;
    if (dx.abs() > dy.abs()) {
      px = dx > 0 ? tx + 1 : tx - 1;
      py = ty;
    } else {
      px = tx;
      py = dy > 0 ? ty + 1 : ty - 1;
    }

    if (worldManager.hasTileAt(px, py)) return false;
    return _tryUseOrPlace(px, py);
  }

  bool _tryUseOrPlace(int x, int y) {
    final slot = inventory.selectedSlot;
    if (slot.isEmpty) return false;

    if (x < 0 || y < 0 || x >= worldWidth || y >= worldHeight) return false;
    if (worldManager.hasTileAt(x, y)) return false;

    final tc = Vector2((x + 0.5) * tileSize, (y + 0.5) * tileSize);
    if (tc.distanceTo(player.center) > player.reach) return false;

    final type = slot.type!;

    if (type == ItemType.tnt) return _placeTnt(x, y);
    if (type == ItemType.teleportGen) return _placeTeleportDoor(x, y);

    return _tryPlace(x, y);
  }

  bool _tryPlace(int x, int y) {
    final slot = inventory.selectedSlot;
    if (slot.isEmpty) return false;
    final spec = itemSpecs[slot.type!];
    if (spec == null || !spec.isPlaceable || spec.tileType == null) {
      return false;
    }

    // Blocks must be adjacent to an existing block
    if (!_hasAdjacentBlock(x, y)) return false;

    final pr = ui.Rect.fromLTWH(
      player.position.x,
      player.position.y,
      player.size.x,
      player.size.y,
    );
    final tr = ui.Rect.fromLTWH(x * tileSize, y * tileSize, tileSize, tileSize);
    if (pr.overlaps(tr)) return false;

    if (worldManager.placeTile(x, y, spec.tileType!)) {
      inventory.removeFromSelected(1);
      return true;
    }
    return false;
  }

  bool _placeTnt(int x, int y) {
    final pos = Vector2(x * tileSize, y * tileSize);
    gameCamera.world?.add(TntComponent(position: pos, sprite: _tntSprite));
    inventory.removeFromSelected(1);
    return true;
  }

  SpriteAnimation buildExplosionAnimation() {
    return SpriteAnimation.spriteList(
      _explosionFrames,
      stepTime: 0.1,
      loop: false,
    );
  }

  SpriteAnimation _buildPortalAnimation() {
    return SpriteAnimation.spriteList(
      _portalFrames,
      stepTime: 0.15,
      loop: true,
    );
  }

  Map<MonsterKind, Map<MonsterAnim, SpriteAnimation>>
  _buildMonsterAnimations() {
    SpriteAnimation strip(String path, int frames, double stepTime) {
      return SpriteAnimation.fromFrameData(
        images.fromCache(path),
        SpriteAnimationData.sequenced(
          amount: frames,
          stepTime: stepTime,
          textureSize: Vector2.all(32),
          loop: true,
        ),
      );
    }

    Map<MonsterAnim, SpriteAnimation> setFor(String prefix) {
      return {
        MonsterAnim.idle: strip('${prefix}_Idle_4.png', 4, 0.14),
        MonsterAnim.walk: strip('${prefix}_Walk_6.png', 6, 0.10),
        MonsterAnim.jump: strip('${prefix}_Jump_8.png', 8, 0.09),
        MonsterAnim.attack: strip('${prefix}_Attack1_4.png', 4, 0.08),
        MonsterAnim.hurt: strip('${prefix}_Hurt_4.png', 4, 0.07),
        MonsterAnim.death: SpriteAnimation.fromFrameData(
          images.fromCache('${prefix}_Death_8.png'),
          SpriteAnimationData.sequenced(
            amount: 8,
            stepTime: 0.08,
            textureSize: Vector2.all(32),
            loop: false,
          ),
        ),
      };
    }

    return {
      MonsterKind.pink: setFor('monsters/1 Pink_Monster/Pink_Monster'),
      MonsterKind.owlet: setFor('monsters/2 Owlet_Monster/Owlet_Monster'),
      MonsterKind.dude: setFor('monsters/3 Dude_Monster/Dude_Monster'),
    };
  }

  bool _placeTeleportDoor(int x, int y) {
    if (gameState.inDungeon) return false;
    final pos = Vector2(x * tileSize, y * tileSize);
    final door = TeleportDoor(
      position: pos,
      id: _nextDoorId++,
      animation: _buildPortalAnimation(),
    );
    doors.add(door);
    gameCamera.world?.add(door);
    inventory.removeFromSelected(1);
    return true;
  }

  /// Keyboard/button: place adjacent to the faced block on the player's side.
  void _placeFacing() {
    final (ftx, fty) = _facingTile();

    if (worldManager.hasTileAt(ftx, fty)) {
      // Faced tile is solid → place on the player's side
      int px, py;
      switch (player.facingDir) {
        case FacingDir.left:
          px = ftx + 1;
          py = fty;
        case FacingDir.right:
          px = ftx - 1;
          py = fty;
        case FacingDir.up:
          px = ftx;
          py = fty + 1;
        case FacingDir.down:
          px = ftx;
          py = fty - 1;
        case FacingDir.upLeft:
          px = ftx + 1;
          py = fty + 1;
        case FacingDir.upRight:
          px = ftx - 1;
          py = fty + 1;
        case FacingDir.downLeft:
          px = ftx + 1;
          py = fty - 1;
        case FacingDir.downRight:
          px = ftx - 1;
          py = fty - 1;
      }
      _tryUseOrPlace(px, py);
    } else {
      // Faced tile is empty → place directly there
      _tryUseOrPlace(ftx, fty);
    }
  }

  // ── Teleport interaction ──────────────────────────────────────────────

  DungeonPortal _newSurfacePortal() {
    return DungeonPortal(
      position: _surfacePortalPos.clone(),
      requiredLevel: 5,
      animation: SpriteAnimation.spriteList(_portalFrames, stepTime: 0.15),
    );
  }

  void _ensureSurfacePortal() {
    final hasSurface = gameWorld.children.whereType<DungeonPortal>().any(
      (p) => !p.isExit,
    );
    if (!hasSurface) {
      gameWorld.add(_newSurfacePortal());
    }
  }

  void _removeAllSurfaceEntities() {
    for (final door in doors) {
      door.removeFromParent();
    }
    gameWorld.children
        .whereType<DungeonPortal>()
        .where((p) => !p.isExit)
        .forEach((p) => p.removeFromParent());
  }

  void _removeAllDungeonEntities() {
    gameWorld.children
        .whereType<DungeonPortal>()
        .where((p) => p.isExit)
        .forEach((p) => p.removeFromParent());
  }

  void _restoreSurfaceEntities() {
    for (final door in doors) {
      if (door.parent == null) {
        gameWorld.add(door);
      }
    }
    _ensureSurfacePortal();
  }

  DungeonPortal? _nearbyDungeonPortal() {
    for (final portal in gameWorld.children.whereType<DungeonPortal>()) {
      if (player.center.distanceTo(portal.center) <= tileSize * 1.8) {
        return portal;
      }
    }
    return null;
  }

  void _openDungeonPortalConfirm(DungeonPortal portal) {
    interactingPortal = portal;
    overlays.add('dungeon_confirm');
  }

  void _tryInteractPortalOrDoor() {
    final portal = _nearbyDungeonPortal();
    if (portal != null) {
      _openDungeonPortalConfirm(portal);
      return;
    }
    _tryInteractDoor();
  }

  void _handleDungeonDeathRecovery() {
    _dungeonFlowState = DungeonFlowState.recovering;
    final run = gameState.activeDungeonRun;
    if (run != null) {
      final result = run.failRun(lossRate: 0.3);
      gameState.dungeonTokens += result.finalTokens;
      _lastDungeonResult = result;
      overlays.add('dungeon_result');
    }
    gameState.activeDungeonRun = null;
    _runElapsedSeconds = 0;
    gameState.worldMode = WorldMode.overworld;
    _removeAllDungeonEntities();
    gameWorld.children.whereType<MonsterComponent>().forEach((m) {
      m.removeFromParent();
    });

    if (_savedOverworldTiles != null) {
      worldManager.loadFromJson(_savedOverworldTiles!);
      if (_savedPlayerPos != null) {
        player.position = _savedPlayerPos!.clone();
      } else {
        player.respawnAtSurface();
      }
    } else {
      worldManager.generate();
      player.respawnAtSurface();
    }
    player.velocity.setZero();
    gameState.activeShieldHits = 0;
    _restoreSurfaceEntities();
    _dungeonFlowState = DungeonFlowState.surface;
  }

  TeleportDoor? _doorAt(int tx, int ty) {
    if (gameState.inDungeon) return null;
    for (final door in doors) {
      final dx = (door.position.x / tileSize).floor();
      final dy = (door.position.y / tileSize).floor();
      if (dx == tx && dy == ty) return door;
    }
    return null;
  }

  TeleportDoor? _nearbyDoor() {
    if (gameState.inDungeon) return null;
    for (final door in doors) {
      if (player.center.distanceTo(door.center) < tileSize * 1.5) {
        return door;
      }
    }
    return null;
  }

  void _tryInteractDoor() {
    final door = _nearbyDoor();
    if (door == null) return;
    interactingDoor = door;
    overlays.add('teleport');
  }

  void teleportTo(TeleportDoor? destination) {
    overlays.remove('teleport');
    if (destination == null) {
      player.respawnAtSurface();
    } else {
      player.position
        ..x = destination.position.x
        ..y = destination.position.y - player.size.y;
      player.velocity.setZero();
    }
    interactingDoor = null;
  }

  void closeTeleport() {
    overlays.remove('teleport');
    interactingDoor = null;
  }

  // ── Overlays ──────────────────────────────────────────────────────────

  void toggleInventory() {
    if (inventoryOpen) {
      overlays.remove('inventory');
      inventoryOpen = false;
    } else {
      overlays.add('inventory');
      inventoryOpen = true;
    }
  }

  void closeInventory() {
    overlays.remove('inventory');
    inventoryOpen = false;
  }

  void closeDeath() => overlays.remove('death');

  void closeDungeonResult() {
    overlays.remove('dungeon_result');
  }

  // ── Keyboard ──────────────────────────────────────────────────────────

  bool _handleKey(KeyEvent event) {
    if (!_loaded) return false;

    // ESC: close inventory, or toggle pause
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (inventoryOpen) {
        closeInventory();
        return true;
      }
      if (_paused) {
        resumeGame();
        overlays.remove('pause');
      } else {
        pauseGame();
        overlays.add('pause');
      }
      return true;
    }

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyE) {
      if (!_paused) toggleInventory();
      return false;
    }

    if (inventoryOpen || _paused) return false;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final left =
        pressed.contains(LogicalKeyboardKey.keyA) ||
        pressed.contains(LogicalKeyboardKey.arrowLeft);
    final right =
        pressed.contains(LogicalKeyboardKey.keyD) ||
        pressed.contains(LogicalKeyboardKey.arrowRight);
    _kbAxis = (right ? 1.0 : 0.0) + (left ? -1.0 : 0.0);

    if (event is KeyDownEvent) {
      final k = event.logicalKey;
      if (k == LogicalKeyboardKey.keyF) _placeFacing();
      if (k == LogicalKeyboardKey.keyT) _tryInteractPortalOrDoor();

      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.digit8,
      ];
      for (var i = 0; i < digits.length; i++) {
        if (k == digits[i]) {
          inventory.select(i);
          break;
        }
      }
    }
    return false;
  }
}
