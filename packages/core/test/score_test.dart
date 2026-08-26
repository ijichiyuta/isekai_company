import 'package:isekai_core/isekai_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  final balance = testBalance();
  final p = ScoreParams.defaults();

  GameState _lifeEnd({
    int funds = 0,
    int fame = 0,
    int discoveries = 0,
    int rank = 0,
    String reason = 'lifespan',
  }) {
    final s = GameState.initial(balance, 1);
    s.funds = funds;
    s.fame = fame;
    s.discoveries = discoveries;
    s.rank = rank;
    s.alive = false;
    s.endReason = reason;
    return s;
  }

  test('score sums the four parts (α/β/γ/δ)', () {
    final s = _lifeEnd(
        funds: 15000000, fame: 3000, discoveries: 40, rank: 4); // 御用達
    final sc = computeLifetimeScore(s, balance, p);
    expect(sc.assetsPart, 15000000 ~/ 100000); // 150
    expect(sc.famePart, 3000 ~/ 10); // 300
    expect(sc.recipesPart, 40 * 20); // 800
    expect(sc.rankPart, 1000); // rank 4 coeff
    expect(sc.total, 150 + 300 + 800 + 1000);
  });

  test('bankruptcy keeps 50%', () {
    final normal = computeLifetimeScore(
        _lifeEnd(funds: 100000, fame: 100, discoveries: 5, rank: 1),
        balance,
        p);
    final broke = computeLifetimeScore(
        _lifeEnd(
            funds: 100000,
            fame: 100,
            discoveries: 5,
            rank: 1,
            reason: 'bankrupt'),
        balance,
        p);
    expect(broke.total, normal.total * 50 ~/ 100);
  });

  test('negative funds score 0 for the assets part', () {
    final sc = computeLifetimeScore(
        _lifeEnd(funds: -500, fame: 50, discoveries: 3), balance, p);
    expect(sc.assetsPart, 0);
    expect(sc.total, greaterThanOrEqualTo(0));
  });

  test('soul points derive from score', () {
    expect(soulPointsFromScore(2500, p), 2500 ~/ p.pointsPerScore);
  });
}
