import 'package:isekai_core/isekai_core.dart';
import 'package:test/test.dart';

void main() {
  test('same seed + stream produces identical sequences', () {
    final a = Pcg32(42, 1);
    final b = Pcg32(42, 1);
    for (var i = 0; i < 100; i++) {
      expect(a.nextUint32(), b.nextUint32());
    }
  });

  test('different streams diverge', () {
    final a = Pcg32(42, 1);
    final b = Pcg32(42, 2);
    var same = 0;
    for (var i = 0; i < 20; i++) {
      if (a.nextUint32() == b.nextUint32()) same++;
    }
    expect(same, lessThan(3));
  });

  test('serialize mid-stream and resume identically', () {
    final a = Pcg32(7, 3);
    for (var i = 0; i < 57; i++) {
      a.nextUint32();
    }
    final restored = Pcg32.fromJson(a.toJson());
    expect(restored.drawCount, 57);
    for (var i = 0; i < 100; i++) {
      expect(restored.nextUint32(), a.nextUint32());
    }
  });

  test('nextInt stays in bounds', () {
    final a = Pcg32(1, 1);
    for (var i = 0; i < 1000; i++) {
      final v = a.nextInt(11);
      expect(v, inInclusiveRange(0, 10));
    }
  });

  test('nextInt rejects bound <= 0 WITHOUT drawing (no desync)', () {
    final a = Pcg32(1, 1);
    final before = a.drawCount;
    expect(() => a.nextInt(0), throwsArgumentError);
    expect(() => a.nextInt(-3), throwsArgumentError);
    // Crucially, the stream did not advance — a caught throw can't desync.
    expect(a.drawCount, before);
  });
}
