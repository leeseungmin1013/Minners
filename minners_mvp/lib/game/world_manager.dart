import 'dart:ui';

import 'package:flame/components.dart';

import 'save_data.dart';
import 'tile_data.dart';
import 'tile_component.dart';

class DungeonConfig {
  final int startX;
  final int startY;
  final int roomWidth;
  final int roomHeight;
  final int seed;
  final double obstacleChance;
  final String themeId;
  final List<Vector2> spawnPoints;
  final Rect? waveAreaBounds;

  const DungeonConfig({
    this.startX = 2,
    this.startY = 5,
    this.roomWidth = 15,
    this.roomHeight = 10,
    this.seed = 0,
    this.obstacleChance = 0.0,
    this.themeId = 'default',
    this.spawnPoints = const [],
    this.waveAreaBounds,
  });
}

class WorldManager {
  late List<List<TileState?>> tiles;
  final Map<int, TileComponent> _visible = {};
  final World world;

  int _lx = -1, _rx = -1, _ty = -1, _by = -1;

  WorldManager({required this.world});

  // ── World generation ─────────────────────────────────────────────────────

  void generate() {
    tiles = List.generate(
      worldHeight,
      (_) => List<TileState?>.filled(worldWidth, null),
    );

    for (var y = 0; y < worldHeight; y++) {
      for (var x = 0; x < worldWidth; x++) {
        if (y < skyRows) {
          continue; // air
        }
        if (y == skyRows) {
          _set(x, y, TileType.grass);
          continue;
        }
        if (y >= worldHeight - 2) {
          _set(x, y, TileType.bedrock);
          continue;
        }
        final type = _pickType(x, y);
        _set(x, y, type);
      }
    }
  }

  void _set(int x, int y, TileType type) {
    tiles[y][x] = TileState(type, tileSpecs[type]!.maxHp.toDouble());
  }

  /// Generate a dungeon room from [config] surrounded by Bedrock.
  void generateDungeon([DungeonConfig config = const DungeonConfig()]) {
    // Resize tiles to small dungeon size if needed, or just clear and use subset
    // Simpler: Reuse global world size but only fill a small corner,
    // or better: Reallocate `tiles` to match dungeon size.
    // Since `worldWidth` is const 80, we might have issues if we shrink `tiles`.
    // Let's stick to using the existing grid but clearing it and building a room at 0,0.

    // Clear everything
    for (var y = 0; y < worldHeight; y++) {
      for (var x = 0; x < worldWidth; x++) {
        tiles[y][x] = null;
        final key = y * worldWidth + x;
        _visible.remove(key)?.removeFromParent();
      }
    }

    final startX = config.startX.clamp(1, worldWidth - 4);
    final startY = config.startY.clamp(1, worldHeight - 4);
    final roomW = config.roomWidth.clamp(5, worldWidth - startX - 2);
    final roomH = config.roomHeight.clamp(4, worldHeight - startY - 2);

    for (var y = startY; y < startY + roomH + 2; y++) {
      for (var x = startX; x < startX + roomW + 2; x++) {
        if (x == startX ||
            x == startX + roomW + 1 ||
            y == startY ||
            y == startY + roomH + 1) {
          _set(x, y, TileType.bedrock);
        } else {
          // Optional interior obstacles for future waves/biomes.
          if (config.obstacleChance > 0 &&
              tileNoise(x, y, config.seed) < config.obstacleChance) {
            _set(x, y, TileType.stone);
          }
        }
      }
    }
  }

  TileType _pickType(int x, int y) {
    final depth = y - skyRows;

    // Ore-vein propagation: extend neighbouring ore clusters
    if (x > 0) {
      final left = tiles[y][x - 1];
      if (left != null && isOre(left.type) && tileNoise(x, y, 1) < 0.38) {
        return left.type;
      }
    }
    if (y > skyRows + 1) {
      final above = tiles[y - 1][x];
      if (above != null && isOre(above.type) && tileNoise(x, y, 2) < 0.28) {
        return above.type;
      }
    }

    final n = tileNoise(x, y);

    if (depth <= 8) return TileType.dirt;

    if (depth <= 20) {
      if (n < 0.07) return TileType.copper;
      if (n < 0.25) return TileType.stone;
      return TileType.dirt;
    }
    if (depth <= 50) {
      if (n < 0.04) return TileType.iron;
      if (n < 0.12) return TileType.copper;
      return TileType.stone;
    }
    if (depth <= 100) {
      if (n < 0.025) return TileType.gold;
      if (n < 0.09) return TileType.iron;
      if (n < 0.17) return TileType.copper;
      return TileType.stone;
    }
    if (depth <= 150) {
      if (n < 0.018) return TileType.diamond;
      if (n < 0.07) return TileType.gold;
      if (n < 0.16) return TileType.iron;
      return TileType.stone;
    }
    // Deepest layers – denser high-value ores
    if (n < 0.045) return TileType.diamond;
    if (n < 0.14) return TileType.gold;
    if (n < 0.28) return TileType.iron;
    return TileType.stone;
  }

  // ── Visible-tile streaming ───────────────────────────────────────────────

  void updateVisibleTiles(Vector2 cameraCenter, Vector2 viewSize) {
    const buf = 3;
    final halfW = viewSize.x / 2;
    final halfH = viewSize.y / 2;

    final lx = ((cameraCenter.x - halfW) / tileSize).floor().clamp(
      0,
      worldWidth - 1,
    );
    final rx = ((cameraCenter.x + halfW) / tileSize).ceil().clamp(
      0,
      worldWidth - 1,
    );
    final ty = ((cameraCenter.y - halfH) / tileSize).floor().clamp(
      0,
      worldHeight - 1,
    );
    final by = ((cameraCenter.y + halfH) / tileSize).ceil().clamp(
      0,
      worldHeight - 1,
    );

    final minX = (lx - buf).clamp(0, worldWidth - 1);
    final maxX = (rx + buf).clamp(0, worldWidth - 1);
    final minY = (ty - buf).clamp(0, worldHeight - 1);
    final maxY = (by + buf).clamp(0, worldHeight - 1);

    if (minX == _lx && maxX == _rx && minY == _ty && maxY == _by) return;

    // Remove out-of-range tiles
    _visible.removeWhere((key, comp) {
      final cx = key % worldWidth;
      final cy = key ~/ worldWidth;
      if (cx < minX || cx > maxX || cy < minY || cy > maxY) {
        comp.removeFromParent();
        return true;
      }
      return false;
    });

    // Add newly visible tiles
    for (var y = minY; y <= maxY; y++) {
      for (var x = minX; x <= maxX; x++) {
        final key = y * worldWidth + x;
        if (_visible.containsKey(key)) continue;
        final state = tiles[y][x];
        if (state == null) continue;

        final comp = TileComponent(gridX: x, gridY: y, state: state);
        _visible[key] = comp;
        world.add(comp);
      }
    }

    _lx = minX;
    _rx = maxX;
    _ty = minY;
    _by = maxY;
  }

  // ── Mining ───────────────────────────────────────────────────────────────

  /// Hit the tile at (x, y). Returns the [TileType] if destroyed, else null.
  TileType? mine(int x, int y, double damage) {
    if (x < 0 || y < 0 || x >= worldWidth || y >= worldHeight) return null;
    final state = tiles[y][x];
    if (state == null) return null;
    if (state.type == TileType.bedrock) return null;

    state.hp -= damage;
    if (state.hp <= 0) {
      final type = state.type;
      tiles[y][x] = null;
      final key = y * worldWidth + x;
      _visible.remove(key)?.removeFromParent();
      return type;
    }
    // Update crack visual
    final key = y * worldWidth + x;
    _visible[key]?.syncVisual();
    return null;
  }

  /// Reset a partially-mined tile back to full HP.
  void resetTileHp(int x, int y) {
    if (x < 0 || y < 0 || x >= worldWidth || y >= worldHeight) return;
    final state = tiles[y][x];
    if (state == null) return;
    state.hp = tileSpecs[state.type]!.maxHp.toDouble();
    final key = y * worldWidth + x;
    _visible[key]?.syncVisual();
  }

  // ── Destroy (instant, for TNT) ──────────────────────────────────────────

  TileType? destroyTile(int x, int y) {
    if (x < 0 || y < 0 || x >= worldWidth || y >= worldHeight) return null;
    final state = tiles[y][x];
    if (state == null) return null;
    if (state.type == TileType.bedrock) return null;

    final type = state.type;
    tiles[y][x] = null;
    final key = y * worldWidth + x;
    _visible.remove(key)?.removeFromParent();
    return type;
  }

  // ── Placing ──────────────────────────────────────────────────────────────

  /// Place a tile. Returns true on success.
  bool placeTile(int x, int y, TileType type) {
    if (x < 0 || y < 0 || x >= worldWidth || y >= worldHeight) return false;
    if (tiles[y][x] != null) return false;

    final spec = tileSpecs[type]!;
    final state = TileState(type, spec.maxHp.toDouble());
    tiles[y][x] = state;

    final key = y * worldWidth + x;
    final comp = TileComponent(gridX: x, gridY: y, state: state);
    _visible[key] = comp;
    world.add(comp);
    return true;
  }

  // ── Queries ────────────────────────────────────────────────────────────

  bool hasTileAt(int x, int y) {
    if (x < 0 || y < 0 || x >= worldWidth || y >= worldHeight) return false;
    return tiles[y][x] != null;
  }

  bool isSolid(int x, int y) {
    if (x < 0 || x >= worldWidth) return true;
    if (y < 0) return false;
    if (y >= worldHeight) return true;
    return tiles[y][x] != null;
  }

  /// Serialize world tiles with RLE compression.
  List<Map<String, dynamic>> tilesToJson() => SaveData.encodeTiles(tiles);

  /// Replace the tile grid from saved data.
  void loadFromJson(List<Map<String, dynamic>> data) {
    // Clear existing visible components
    for (final comp in _visible.values) {
      comp.removeFromParent();
    }
    _visible.clear();
    _lx = _rx = _ty = _by = -1;

    // Decode tiles into the grid
    tiles = SaveData.decodeTiles(data);
  }
}
