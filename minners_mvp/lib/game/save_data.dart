import 'tile_data.dart';

/// All data needed to fully restore a game session.
class SaveData {
  final String id;
  final String name;
  final DateTime timestamp;
  final int playtimeSeconds;

  // Player
  final double playerX;
  final double playerY;
  final double velocityX;
  final double velocityY;
  final String worldMode;

  // GameState
  final int hp;
  final int maxHp;
  final int gold;
  final int level;
  final int xp;
  final int dungeonTokens;
  final int combatDamageBonusLevel;
  final int dungeonShieldCharges;
  final String pickaxeTier;
  final bool hasJetpack;
  final double jetpackFuel;
  final double jetpackMaxFuel;

  // Inventory (48 slots: 8 hotbar + 40 main)
  final List<Map<String, dynamic>> inventorySlots;
  final int selectedHotbar;

  // World tiles (only non-null stored)
  final List<Map<String, dynamic>> tiles;
  final List<Map<String, dynamic>>? overworldSnapshot;
  final List<Map<String, dynamic>>? dungeonSnapshot;
  final double? overworldPlayerX;
  final double? overworldPlayerY;
  final double? dungeonPlayerX;
  final double? dungeonPlayerY;
  final String? lastDungeonType;
  final int? lastClearedWave;
  final String? activeDungeonType;
  final int? activeDungeonWave;
  final int? activeDungeonRunToken;
  final int? activeDungeonRunDamage;
  final double? activeDungeonElapsed;

  // Teleport doors
  final List<Map<String, dynamic>> doors;

  SaveData({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.playtimeSeconds,
    required this.playerX,
    required this.playerY,
    required this.velocityX,
    required this.velocityY,
    required this.worldMode,
    required this.hp,
    required this.maxHp,
    required this.gold,
    required this.level,
    required this.xp,
    required this.dungeonTokens,
    required this.combatDamageBonusLevel,
    required this.dungeonShieldCharges,
    required this.pickaxeTier,
    required this.hasJetpack,
    required this.jetpackFuel,
    required this.jetpackMaxFuel,
    required this.inventorySlots,
    required this.selectedHotbar,
    required this.tiles,
    this.overworldSnapshot,
    this.dungeonSnapshot,
    this.overworldPlayerX,
    this.overworldPlayerY,
    this.dungeonPlayerX,
    this.dungeonPlayerY,
    this.lastDungeonType,
    this.lastClearedWave,
    this.activeDungeonType,
    this.activeDungeonWave,
    this.activeDungeonRunToken,
    this.activeDungeonRunDamage,
    this.activeDungeonElapsed,
    required this.doors,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'timestamp': timestamp.toIso8601String(),
    'playtimeSeconds': playtimeSeconds,
    'playerX': playerX,
    'playerY': playerY,
    'velocityX': velocityX,
    'velocityY': velocityY,
    'worldMode': worldMode,
    'hp': hp,
    'maxHp': maxHp,
    'gold': gold,
    'level': level,
    'xp': xp,
    'dungeonTokens': dungeonTokens,
    'combatDamageBonusLevel': combatDamageBonusLevel,
    'dungeonShieldCharges': dungeonShieldCharges,
    'pickaxeTier': pickaxeTier,
    'hasJetpack': hasJetpack,
    'jetpackFuel': jetpackFuel,
    'jetpackMaxFuel': jetpackMaxFuel,
    'inventorySlots': inventorySlots,
    'selectedHotbar': selectedHotbar,
    'tiles': tiles,
    'overworldSnapshot': overworldSnapshot,
    'dungeonSnapshot': dungeonSnapshot,
    'overworldPlayerX': overworldPlayerX,
    'overworldPlayerY': overworldPlayerY,
    'dungeonPlayerX': dungeonPlayerX,
    'dungeonPlayerY': dungeonPlayerY,
    'lastDungeonType': lastDungeonType,
    'lastClearedWave': lastClearedWave,
    'activeDungeonType': activeDungeonType,
    'activeDungeonWave': activeDungeonWave,
    'activeDungeonRunToken': activeDungeonRunToken,
    'activeDungeonRunDamage': activeDungeonRunDamage,
    'activeDungeonElapsed': activeDungeonElapsed,
    'doors': doors,
  };

  factory SaveData.fromJson(Map<String, dynamic> json) => SaveData(
    id: json['id'] as String,
    name: json['name'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    playtimeSeconds: json['playtimeSeconds'] as int,
    playerX: (json['playerX'] as num).toDouble(),
    playerY: (json['playerY'] as num).toDouble(),
    velocityX: (json['velocityX'] as num).toDouble(),
    velocityY: (json['velocityY'] as num).toDouble(),
    worldMode: json['worldMode'] as String? ?? 'overworld',
    hp: json['hp'] as int,
    maxHp: json['maxHp'] as int,
    gold: json['gold'] as int,
    level: json['level'] as int? ?? 0,
    xp: json['xp'] as int? ?? 0,
    dungeonTokens: json['dungeonTokens'] as int? ?? 0,
    combatDamageBonusLevel: json['combatDamageBonusLevel'] as int? ?? 0,
    dungeonShieldCharges: json['dungeonShieldCharges'] as int? ?? 0,
    pickaxeTier: json['pickaxeTier'] as String,
    hasJetpack: json['hasJetpack'] as bool,
    jetpackFuel: (json['jetpackFuel'] as num).toDouble(),
    jetpackMaxFuel: (json['jetpackMaxFuel'] as num).toDouble(),
    inventorySlots: (json['inventorySlots'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    selectedHotbar: json['selectedHotbar'] as int,
    tiles: (json['tiles'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    overworldSnapshot: (json['overworldSnapshot'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    dungeonSnapshot: (json['dungeonSnapshot'] as List?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
    overworldPlayerX: (json['overworldPlayerX'] as num?)?.toDouble(),
    overworldPlayerY: (json['overworldPlayerY'] as num?)?.toDouble(),
    dungeonPlayerX: (json['dungeonPlayerX'] as num?)?.toDouble(),
    dungeonPlayerY: (json['dungeonPlayerY'] as num?)?.toDouble(),
    lastDungeonType: json['lastDungeonType'] as String?,
    lastClearedWave: json['lastClearedWave'] as int?,
    activeDungeonType: json['activeDungeonType'] as String?,
    activeDungeonWave: json['activeDungeonWave'] as int?,
    activeDungeonRunToken: json['activeDungeonRunToken'] as int?,
    activeDungeonRunDamage: json['activeDungeonRunDamage'] as int?,
    activeDungeonElapsed: (json['activeDungeonElapsed'] as num?)?.toDouble(),
    doors: (json['doors'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(),
  );

  /// Encode world tiles with RLE compression.
  /// Consecutive tiles of same type at full HP in the same row → {y, x1, x2, type}
  /// Otherwise individual tile → {x, y, type, hp}
  static List<Map<String, dynamic>> encodeTiles(
    List<List<TileState?>> worldTiles,
  ) {
    final result = <Map<String, dynamic>>[];
    for (var y = 0; y < worldTiles.length; y++) {
      final row = worldTiles[y];
      var x = 0;
      while (x < row.length) {
        final state = row[x];
        if (state == null) {
          x++;
          continue;
        }
        final maxHp = tileSpecs[state.type]!.maxHp.toDouble();
        final isFullHp = (state.hp - maxHp).abs() < 0.01;

        if (isFullHp) {
          // Try RLE: find consecutive same-type full-HP tiles
          var x2 = x;
          while (x2 + 1 < row.length) {
            final next = row[x2 + 1];
            if (next == null || next.type != state.type) break;
            final nextMax = tileSpecs[next.type]!.maxHp.toDouble();
            if ((next.hp - nextMax).abs() >= 0.01) break;
            x2++;
          }
          if (x2 > x) {
            // RLE entry
            result.add({'y': y, 'x1': x, 'x2': x2, 't': state.type.index});
          } else {
            // Single full-HP tile
            result.add({'x': x, 'y': y, 't': state.type.index});
          }
          x = x2 + 1;
        } else {
          // Damaged tile - store with HP
          result.add({'x': x, 'y': y, 't': state.type.index, 'h': state.hp});
          x++;
        }
      }
    }
    return result;
  }

  /// Decode tiles back to the world grid.
  static List<List<TileState?>> decodeTiles(List<Map<String, dynamic>> data) {
    final tiles = List.generate(
      worldHeight,
      (_) => List<TileState?>.filled(worldWidth, null),
    );
    for (final entry in data) {
      final y = entry['y'] as int;
      final typeIdx = entry['t'] as int;
      final type = TileType.values[typeIdx];
      final maxHp = tileSpecs[type]!.maxHp.toDouble();

      if (entry.containsKey('x1')) {
        // RLE entry
        final x1 = entry['x1'] as int;
        final x2 = entry['x2'] as int;
        for (var x = x1; x <= x2; x++) {
          tiles[y][x] = TileState(type, maxHp);
        }
      } else {
        final x = entry['x'] as int;
        final hp = entry.containsKey('h')
            ? (entry['h'] as num).toDouble()
            : maxHp;
        tiles[y][x] = TileState(type, hp);
      }
    }
    return tiles;
  }
}

/// Lightweight metadata for save list (no world data).
class SaveMetadata {
  final String id;
  final String name;
  final DateTime timestamp;
  final int gold;
  final int playtimeSeconds;

  SaveMetadata({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.gold,
    required this.playtimeSeconds,
  });

  factory SaveMetadata.fromJson(Map<String, dynamic> json) => SaveMetadata(
    id: json['id'] as String,
    name: json['name'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    gold: json['gold'] as int,
    playtimeSeconds: json['playtimeSeconds'] as int,
  );
}
