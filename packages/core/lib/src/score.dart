/// Lifetime score (requirements §8.2). Computed from the final state at life
/// end. Integer-only (no floating point in core, §2.2). Coefficients live in
/// balance so they can be tuned without code changes.
library;

import 'balance.dart';
import 'state.dart';

class LifetimeScore {
  final int assetsPart;
  final int famePart;
  final int recipesPart;
  final int rankPart;
  final int total;
  const LifetimeScore({
    required this.assetsPart,
    required this.famePart,
    required this.recipesPart,
    required this.rankPart,
    required this.total,
  });
}

/// score = assets/α + fame/β + recipes×γ + rankCoeff(rank)
///         then × earlyRetire penalty (if applicable) × difficulty (MVP: 1).
///
/// Bankruptcy keeps 50% and drops the (unimplemented) achievement term (§8.1).
LifetimeScore computeLifetimeScore(GameState s, Balance b, ScoreParams p) {
  // Assets floor at 0 for scoring (a negative bankruptcy balance scores 0 here).
  final assets = s.funds < 0 ? 0 : s.funds;
  final assetsPart = assets ~/ p.assetsPerPoint; // α
  final famePart = s.fame ~/ p.famePerPoint; // β
  final recipesPart = s.discoveries * p.recipePoints; // γ
  final rankPart = p.rankCoeff[s.rank]; // δ

  var total = assetsPart + famePart + recipesPart + rankPart;

  // Bankruptcy: 50% (ε achievement term already excluded — not yet modeled).
  if (s.endReason == 'bankrupt') {
    total = total * p.bankruptcyPctX100 ~/ 100;
  }
  return LifetimeScore(
    assetsPart: assetsPart,
    famePart: famePart,
    recipesPart: recipesPart,
    rankPart: rankPart,
    total: total,
  );
}

/// "Soul memory" points earned from a life = score ~/ divisor (§8.2/§8.4).
int soulPointsFromScore(int score, ScoreParams p) =>
    score ~/ p.pointsPerScore;

class ScoreParams {
  final int assetsPerPoint; // α: 1pt per this many G
  final int famePerPoint; // β: 1pt per this much fame
  final int recipePoints; // γ: pt per discovered recipe
  final List<int> rankCoeff; // δ: by rank id
  final int bankruptcyPctX100; // §8.1: 50%
  final int pointsPerScore; // score → soul points divisor
  const ScoreParams({
    required this.assetsPerPoint,
    required this.famePerPoint,
    required this.recipePoints,
    required this.rankCoeff,
    required this.bankruptcyPctX100,
    required this.pointsPerScore,
  });

  /// Initial values from requirements §8.2 (α=1pt/10万G, β=1pt/10名声,
  /// γ=20pt/種, δ per rank). Loaded from balance in v1.0; inlined for M2.
  factory ScoreParams.defaults() => const ScoreParams(
        assetsPerPoint: 100000,
        famePerPoint: 10,
        recipePoints: 20,
        rankCoeff: [0, 50, 150, 400, 1000, 2500],
        bankruptcyPctX100: 50,
        pointsPerScore: 1,
      );
}
