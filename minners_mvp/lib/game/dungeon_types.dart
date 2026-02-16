import 'monster_component.dart';
import 'world_manager.dart';

enum DungeonType { cavern, ruins, abyss }

class DungeonTypeSpec {
  final DungeonType type;
  final String name;
  final String description;
  final int unlockLevel;
  final int totalWaves;
  final int baseSpawnCount;
  final int spawnGrowthPerWave;
  final int tokenPerWave;
  final int speedBonusSeconds;
  final DungeonConfig config;
  final Map<MonsterKind, double> monsterWeights;

  const DungeonTypeSpec({
    required this.type,
    required this.name,
    required this.description,
    required this.unlockLevel,
    required this.totalWaves,
    required this.baseSpawnCount,
    required this.spawnGrowthPerWave,
    required this.tokenPerWave,
    required this.speedBonusSeconds,
    required this.config,
    required this.monsterWeights,
  });

  int spawnCountForWave(int wave) {
    final w = wave < 1 ? 1 : wave;
    return baseSpawnCount + (w - 1) * spawnGrowthPerWave;
  }
}

const Map<DungeonType, DungeonTypeSpec> dungeonTypeSpecs = {
  DungeonType.cavern: DungeonTypeSpec(
    type: DungeonType.cavern,
    name: 'Cavern',
    description: '입문 던전',
    unlockLevel: 5,
    totalWaves: 5,
    baseSpawnCount: 3,
    spawnGrowthPerWave: 1,
    tokenPerWave: 8,
    speedBonusSeconds: 80,
    config: DungeonConfig(
      startX: 2,
      startY: 5,
      roomWidth: 15,
      roomHeight: 10,
      seed: 23,
      obstacleChance: 0.05,
      themeId: 'cavern',
    ),
    monsterWeights: {
      MonsterKind.pink: 0.7,
      MonsterKind.owlet: 0.3,
      MonsterKind.dude: 0.0,
    },
  ),
  DungeonType.ruins: DungeonTypeSpec(
    type: DungeonType.ruins,
    name: 'Ruins',
    description: '중급 던전',
    unlockLevel: 10,
    totalWaves: 7,
    baseSpawnCount: 4,
    spawnGrowthPerWave: 1,
    tokenPerWave: 14,
    speedBonusSeconds: 110,
    config: DungeonConfig(
      startX: 2,
      startY: 5,
      roomWidth: 17,
      roomHeight: 11,
      seed: 41,
      obstacleChance: 0.09,
      themeId: 'ruins',
    ),
    monsterWeights: {
      MonsterKind.pink: 0.35,
      MonsterKind.owlet: 0.40,
      MonsterKind.dude: 0.25,
    },
  ),
  DungeonType.abyss: DungeonTypeSpec(
    type: DungeonType.abyss,
    name: 'Abyss',
    description: '상급 던전',
    unlockLevel: 15,
    totalWaves: 10,
    baseSpawnCount: 5,
    spawnGrowthPerWave: 2,
    tokenPerWave: 22,
    speedBonusSeconds: 140,
    config: DungeonConfig(
      startX: 1,
      startY: 5,
      roomWidth: 19,
      roomHeight: 12,
      seed: 73,
      obstacleChance: 0.12,
      themeId: 'abyss',
    ),
    monsterWeights: {
      MonsterKind.pink: 0.20,
      MonsterKind.owlet: 0.35,
      MonsterKind.dude: 0.45,
    },
  ),
};
