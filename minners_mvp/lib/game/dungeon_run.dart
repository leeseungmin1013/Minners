import 'dungeon_types.dart';

class DungeonWaveReward {
  final int base;
  final int noHitBonus;
  final int speedBonus;

  const DungeonWaveReward({
    required this.base,
    required this.noHitBonus,
    required this.speedBonus,
  });

  int get total => base + noHitBonus + speedBonus;
}

class DungeonRunResult {
  final DungeonType type;
  final bool cleared;
  final int reachedWave;
  final int earnedTokens;
  final int lostTokens;
  final int finalTokens;

  const DungeonRunResult({
    required this.type,
    required this.cleared,
    required this.reachedWave,
    required this.earnedTokens,
    required this.lostTokens,
    required this.finalTokens,
  });
}

class DungeonRunState {
  final DungeonType type;
  final int totalWaves;
  int currentWave = 0;

  int runTokenEarned = 0;
  int runDamageTaken = 0;
  double waveStartTime = 0;
  int waveStartDamageTaken = 0;

  DungeonRunState({required this.type, required this.totalWaves});

  void startWave(double currentRunTimeSeconds) {
    currentWave += 1;
    waveStartTime = currentRunTimeSeconds;
    waveStartDamageTaken = runDamageTaken;
  }

  void onDamageTaken(int amount) {
    if (amount <= 0) return;
    runDamageTaken += amount;
  }

  DungeonWaveReward completeWave({
    required DungeonTypeSpec spec,
    required double currentRunTimeSeconds,
  }) {
    final base = spec.tokenPerWave;
    final tookDamageInWave = runDamageTaken > waveStartDamageTaken;
    final noHitBonus = tookDamageInWave ? 0 : (base * 0.2).floor();
    final elapsed = currentRunTimeSeconds - waveStartTime;
    final speedBonus = elapsed <= spec.speedBonusSeconds
        ? (base * 0.1).floor()
        : 0;

    final reward = DungeonWaveReward(
      base: base,
      noHitBonus: noHitBonus,
      speedBonus: speedBonus,
    );
    runTokenEarned += reward.total;
    return reward;
  }

  bool get isCleared => currentWave >= totalWaves;

  DungeonRunResult failRun({double lossRate = 0.3}) {
    final lost = (runTokenEarned * lossRate).floor();
    final finalTokens = runTokenEarned - lost;
    return DungeonRunResult(
      type: type,
      cleared: false,
      reachedWave: currentWave,
      earnedTokens: runTokenEarned,
      lostTokens: lost,
      finalTokens: finalTokens,
    );
  }

  DungeonRunResult finalizeRun() {
    return DungeonRunResult(
      type: type,
      cleared: true,
      reachedWave: currentWave,
      earnedTokens: runTokenEarned,
      lostTokens: 0,
      finalTokens: runTokenEarned,
    );
  }
}
