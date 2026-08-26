import 'package:isekai_headless/isekai_headless.dart';
import 'package:test/test.dart';

void main() {
  group('percentileSorted (nearest-rank, deterministic)', () {
    test('boundaries and typical values', () {
      final xs = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      expect(percentileSorted(xs, 0), 1);
      expect(percentileSorted(xs, 100), 10);
      expect(percentileSorted(xs, 50), 5);
      expect(percentileSorted(xs, 90), 9);
      expect(percentileSorted(<int>[], 50), 0);
      expect(percentileSorted([42], 50), 42);
    });
  });

  group('IntervalStats', () {
    test('few rewards → whole life is the gap', () {
      final s = IntervalStats.fromRewardTicks([5], 2880);
      expect(s.maxGapTicks, 2880);
      expect(s.rewardCount, 1);
    });

    test('evenly spaced rewards give small gaps; tail counts', () {
      // rewards at 10,20,30; life 100 → tail gap 70 dominates maxGap.
      final s = IntervalStats.fromRewardTicks([10, 20, 30], 100);
      expect(s.maxGapTicks, 70);
      expect(s.p50GapTicks, greaterThanOrEqualTo(10));
    });

    test('tick→seconds conversion (×1速 1.5s/tick)', () {
      final s = IntervalStats.fromRewardTicks([0, 20], 40);
      expect(s.p50Seconds, 20 * 3 ~/ 2); // 30s
    });
  });

  test('median helper', () {
    expect(median([3, 1, 2]), 2);
    expect(median([10]), 10);
  });

  test('evaluateGate runs and classifies hard/soft (small N)', () {
    final balance = loadBalanceFromDir('../../assets/balance');
    final report = evaluateGate(balance, lives: 20, seedBase: 1);
    // The report contains AC-04/05/07/08/10 rows.
    final acs = report.results.map((r) => r.ac).toSet();
    expect(acs.containsAll({'AC-04', 'AC-05', 'AC-07', 'AC-08', 'AC-10'}),
        isTrue);
    // AC-07 (bankruptcy) is a hard gate.
    expect(report.results.any((r) => r.ac == 'AC-07' && r.hard), isTrue);
    // AC-10 is soft (structurally unreachable pre-M3 automation).
    expect(report.results.firstWhere((r) => r.ac == 'AC-10').hard, isFalse);
    // With the current balance, steady never goes bankrupt → hard gates pass.
    expect(report.ok, isTrue);
  });
}
