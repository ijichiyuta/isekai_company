/// Deterministic integer statistics for the balance gates (§18, AC-05).
/// Integer-only, nearest-rank percentiles (no floating point in results).
library;

/// Nearest-rank percentile of an ALREADY-SORTED ascending int list.
/// p in [0,100]. Empty → 0.
int percentileSorted(List<int> sorted, int p) {
  if (sorted.isEmpty) return 0;
  if (p <= 0) return sorted.first;
  if (p >= 100) return sorted.last;
  // rank = ceil(p/100 * n), 1-based → index rank-1.
  final n = sorted.length;
  var rank = (p * n + 99) ~/ 100; // ceil(p*n/100)
  if (rank < 1) rank = 1;
  if (rank > n) rank = n;
  return sorted[rank - 1];
}

/// Reward-pacing stats from the ticks at which rewards fired (§10.4/AC-05).
/// gaps = differences between consecutive reward ticks (a reward on tick 0 has
/// no preceding gap). 1 tick = 1.5s at ×1 speed.
class IntervalStats {
  final int p50GapTicks;
  final int p90GapTicks;
  final int maxGapTicks;
  final int rewardCount;
  const IntervalStats({
    required this.p50GapTicks,
    required this.p90GapTicks,
    required this.maxGapTicks,
    required this.rewardCount,
  });

  factory IntervalStats.fromRewardTicks(List<int> rewardTicks, int lifeWeeks) {
    if (rewardTicks.length < 2) {
      // No measurable gaps → treat the whole life as one long gap.
      return IntervalStats(
        p50GapTicks: lifeWeeks,
        p90GapTicks: lifeWeeks,
        maxGapTicks: lifeWeeks,
        rewardCount: rewardTicks.length,
      );
    }
    final gaps = <int>[];
    for (var i = 1; i < rewardTicks.length; i++) {
      gaps.add(rewardTicks[i] - rewardTicks[i - 1]);
    }
    // Include the tail gap from the last reward to the end of life — a long
    // reward-free run at the end must count against maxGap.
    gaps.add(lifeWeeks - rewardTicks.last);
    gaps.sort();
    return IntervalStats(
      p50GapTicks: percentileSorted(gaps, 50),
      p90GapTicks: percentileSorted(gaps, 90),
      maxGapTicks: gaps.last,
      rewardCount: rewardTicks.length,
    );
  }

  static const secondsPerTick = 3; // ×1速 1.5s → integer via /2 below
  int get p50Seconds => p50GapTicks * 3 ~/ 2;
  int get p90Seconds => p90GapTicks * 3 ~/ 2;
  int get maxGapSeconds => maxGapTicks * 3 ~/ 2;
}

/// Median of an int list (nearest-rank p50). Sorts a copy.
int median(List<int> xs) {
  final s = List<int>.of(xs)..sort();
  return percentileSorted(s, 50);
}
