import 'package:isekai_core/isekai_core.dart';
import 'package:test/test.dart';

void main() {
  test('applyBp does not overflow at the 1e15 cap (the Critical bug)', () {
    // Pre-fix this evaluated 1e15 * 10000 first and wrapped negative.
    expect(applyBp(gameValueCap, 10000), gameValueCap); // 100%
    expect(applyBp(gameValueCap, 800), 80000000000000); // 8% tax
    expect(applyBp(gameValueCap, 500), 50000000000000); // 5%
  });

  test('applyBp matches naive formula for in-range values', () {
    for (final (v, bp) in [(1000, 500), (12, 250), (99999, 800), (7, 10000)]) {
      expect(applyBp(v, bp), v * bp ~/ 10000, reason: 'v=$v bp=$bp');
    }
  });

  test('applyBp truncates toward zero for negatives', () {
    expect(applyBp(-7, 500), -7 * 500 ~/ 10000); // 0
    expect(applyBp(-100, 500), -5);
    expect(applyBp(-12345, 3333), -12345 * 3333 ~/ 10000);
  });

  test('applyX100 is overflow-safe and correct', () {
    // Input is clamped to the cap; the product (2.5e15) still fits int64.
    expect(applyX100(gameValueCap, 250), 2500000000000000);
    expect(applyX100(12, 2500), 300); // pudding invention bonus
    expect(applyX100(-8, 150), -8 * 150 ~/ 100);
  });

  test('clampCap bounds both directions', () {
    expect(clampCap(gameValueCap + 1), gameValueCap);
    expect(clampCap(-gameValueCap - 1), -gameValueCap);
    expect(clampCap(42), 42);
  });
}
