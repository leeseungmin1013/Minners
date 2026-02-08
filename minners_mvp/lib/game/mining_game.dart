import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tile_data.dart';
import 'game_state.dart';
import 'inventory.dart';
import 'player_component.dart';
import 'world_manager.dart';
import 'hud_component.dart';
import 'tnt_component.dart';
import 'teleport_door.dart';

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

class MiningGame extends FlameGame with TapCallbacks {
  final GameState gameState = GameState();
  late final WorldManager worldManager;
  late final PlayerComponent player;
  late final CameraComponent gameCamera;
  late final _CameraTarget _cameraTarget;
  late final _FacingOutline _facingOutline;
  JoystickComponent? _joystick;
  HudComponent? _hud;

  double _kbAxis = 0;
  bool _loaded = false;
  bool inventoryOpen = false;
  bool _btnJumpHeld = false;

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

  Inventory get inventory => gameState.inventory;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    HardwareKeyboard.instance.addHandler(_handleKey);

    final gameWorld = World();
    gameCamera = CameraComponent.withFixedResolution(
      world: gameWorld,
      width: 640,
      height: 360,
    );
    addAll([gameWorld, gameCamera]);

    // Sky
    gameWorld.add(
      RectangleComponent(
        position: Vector2.zero(),
        size: Vector2(worldWidth * tileSize, skyRows * tileSize),
        paint: Paint()..color = const Color(0xFF87CEEB),
        priority: -1,
      ),
    );

    // World
    worldManager = WorldManager(world: gameWorld);
    worldManager.generate();

    // Player
    player = PlayerComponent(
      position: Vector2(
        worldWidth * tileSize / 2,
        (skyRows - 2) * tileSize.toDouble(),
      ),
    );
    gameWorld.add(player);

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

    // ── Controls ───────────────────────────────────────────────────────────
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

    final hud = HudComponent();
    _hud = hud;

    gameCamera.viewport.addAll([joystick, jumpBtn, mineBtn, placeBtn, hud]);
    _loaded = true;
  }

  @override
  void onRemove() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    super.onRemove();
  }

  // ── Update ───────────────────────────────────────────────────────────────

  @override
  void update(double dt) {
    super.update(dt);
    if (!_loaded) return;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;

    // ── Movement & facing ─────────────────────────────────────────────────
    if (!inventoryOpen) {
      final jx = _joystick!.relativeDelta.x.clamp(-1.0, 1.0);
      final jy = _joystick!.relativeDelta.y.clamp(-1.0, 1.0);
      player.setMoveInput(jx.abs() > 0.1 ? jx : _kbAxis);

      // Joystick vertical → set facing
      if (jy < -0.4) player.facingDir = FacingDir.up;
      if (jy > 0.4) player.facingDir = FacingDir.down;

      // Keyboard facing (overrides joystick if pressed)
      if (pressed.contains(LogicalKeyboardKey.keyW) ||
          pressed.contains(LogicalKeyboardKey.arrowUp)) {
        player.facingDir = FacingDir.up;
      }
      if (pressed.contains(LogicalKeyboardKey.keyS) ||
          pressed.contains(LogicalKeyboardKey.arrowDown)) {
        player.facingDir = FacingDir.down;
      }
    } else {
      player.setMoveInput(0);
    }

    // Jump held = keyboard OR mobile button
    final kbJump =
        !inventoryOpen &&
        (pressed.contains(LogicalKeyboardKey.space) ||
            pressed.contains(LogicalKeyboardKey.arrowUp) ||
            pressed.contains(LogicalKeyboardKey.keyW));
    player.jumpHeld = kbJump || _btnJumpHeld;

    // ── Continuous mining (mine button / left-click only) ─────────────────
    int curMineTx = -1, curMineTy = -1;

    if (_tapMineHeld) {
      // Left-click hold takes priority
      if (worldManager.hasTileAt(_tapMineTx, _tapMineTy)) {
        curMineTx = _tapMineTx;
        curMineTy = _tapMineTy;
        _tryMineDps(_tapMineTx, _tapMineTy, dt);
      } else {
        _tapMineHeld = false;
      }
    } else if (!inventoryOpen &&
        (_btnMineHeld ||
            pressed.contains(LogicalKeyboardKey.shiftLeft) ||
            pressed.contains(LogicalKeyboardKey.shiftRight))) {
      final (tx, ty) = _facingTile();
      curMineTx = tx;
      curMineTy = ty;
      _tryMineDps(tx, ty, dt);
    }

    // Reset partially-mined tile when target changes or mining stops
    if (_activeMiningTx != curMineTx || _activeMiningTy != curMineTy) {
      if (_activeMiningTx >= 0) {
        worldManager.resetTileHp(_activeMiningTx, _activeMiningTy);
      }
    }
    _activeMiningTx = curMineTx;
    _activeMiningTy = curMineTy;

    // ── Facing outline indicator ─────────────────────────────────────────
    _updateFacingOutline();

    // ── World / HUD ──────────────────────────────────────────────────────
    worldManager.updateVisibleTiles(
      gameCamera.viewfinder.position,
      Vector2(640, 360),
    );

    _hud?.updateFrom(gameState, player.depth);

    if (gameState.isDead && !overlays.isActive('death')) {
      gameState.die();
      player.respawnAtSurface();
      overlays.add('death');
    }
  }

  void _updateFacingOutline() {
    final (ftx, fty) = _facingTile();
    if (worldManager.hasTileAt(ftx, fty)) {
      _facingOutline.position
        ..x = ftx * tileSize
        ..y = fty * tileSize;
      _facingOutline.visible = true;

      // Mining progress: show green outline proportional to damage dealt
      if (_activeMiningTx == ftx && _activeMiningTy == fty) {
        final state = worldManager.tiles[fty][ftx]!;
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

  // ── Left click → mine ─────────────────────────────────────────────────

  @override
  void onTapDown(TapDownEvent event) {
    if (!_loaded || inventoryOpen) return;
    final wp = gameCamera.globalToLocal(event.canvasPosition);
    final tx = (wp.x / tileSize).floor();
    final ty = (wp.y / tileSize).floor();

    if (worldManager.hasTileAt(tx, ty)) {
      // Left click on block → hold-to-mine
      _tapMineHeld = true;
      _tapMineTx = tx;
      _tapMineTy = ty;
    } else {
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
    if (!_loaded || inventoryOpen) return;
    final wp = gameCamera.globalToLocal(Vector2(screenPos.dx, screenPos.dy));
    final tx = (wp.x / tileSize).floor();
    final ty = (wp.y / tileSize).floor();

    if (worldManager.hasTileAt(tx, ty)) {
      // Right click on block → place adjacent on cursor side
      _placeAdjacentToBlock(tx, ty, wp);
    } else {
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
    switch (player.facingDir) {
      case FacingDir.left:
        return (px - 1, centerY);
      case FacingDir.right:
        return (px + 1, centerY);
      case FacingDir.up:
        return (px, centerY - 1);
      case FacingDir.down:
        final belowY = ((player.position.y + player.size.y) / tileSize).floor();
        return (px, belowY);
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
      return true;
    }
    return worldManager.hasTileAt(x, y);
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
    if (spec == null || !spec.isPlaceable || spec.tileType == null)
      return false;

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
    gameCamera.world?.add(TntComponent(position: pos));
    inventory.removeFromSelected(1);
    return true;
  }

  bool _placeTeleportDoor(int x, int y) {
    final pos = Vector2(x * tileSize, y * tileSize);
    final door = TeleportDoor(position: pos, id: _nextDoorId++);
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
      }
      _tryUseOrPlace(px, py);
    } else {
      // Faced tile is empty → place directly there
      _tryUseOrPlace(ftx, fty);
    }
  }

  // ── Teleport interaction ──────────────────────────────────────────────

  TeleportDoor? _doorAt(int tx, int ty) {
    for (final door in doors) {
      final dx = (door.position.x / tileSize).floor();
      final dy = (door.position.y / tileSize).floor();
      if (dx == tx && dy == ty) return door;
    }
    return null;
  }

  TeleportDoor? _nearbyDoor() {
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

  // ── Keyboard ──────────────────────────────────────────────────────────

  bool _handleKey(KeyEvent event) {
    if (!_loaded) return false;

    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyE) {
      toggleInventory();
      return false;
    }

    if (inventoryOpen) return false;

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
      if (k == LogicalKeyboardKey.keyT) _tryInteractDoor();

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
