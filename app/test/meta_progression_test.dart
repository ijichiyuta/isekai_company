import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/game_controller.dart';
import 'package:isekai_app/game/save_store.dart';
import 'package:isekai_app/game/tick_clock.dart';
import 'package:isekai_core/isekai_core.dart';

import 'helpers.dart';

void main() {
  late Balance balance;
  setUpAll(() => balance = loadTestBalanceFull());

  test(
    'rebirth grants the auto unlock → 2周目 starts at a higher rank (§8.4 #3)',
    () {
      final g = GameController(
        balance: balance,
        clock: FakeTickClock(),
        seed: 1,
      );
      expect(g.state.rank, 0); // 1周目 starts at 行商人
      g.retire();
      g.rebirth();
      final auto = balance.unlocks.firstWhere((u) => u.tier == 'auto');
      expect(
        g.meta.isUnlocked(auto.id),
        isTrue,
      ); // granted on completing a life
      expect(g.state.rank, greaterThan(0)); // 2周目 starts above 行商人 (C-6短縮)
    },
  );

  test(
    'purchaseUnlock spends soul points and advantages the next life (C-6)',
    () {
      final g = GameController(
        balance: balance,
        clock: FakeTickClock(),
        seed: 1,
      );
      g.meta.soulPoints = 5000; // arrange banked points
      final s1 = balance.unlocks.firstWhere((u) => u.key == 'savings_1');
      expect(g.purchaseUnlock(s1.id), isTrue);
      expect(g.soulPointsTotal, 5000 - s1.cost);
      expect(g.meta.isUnlocked(s1.id), isTrue);
      // A prereq-gated node is refused until its requirement is owned.
      final s3 = balance.unlocks.firstWhere((u) => u.key == 'savings_3');
      expect(g.purchaseUnlock(s3.id), isFalse); // needs savings_2 first

      g.retire();
      g.rebirth(); // life 2: +500 start funds from savings_1
      expect(g.state.funds, balance.economy.startFunds + s1.modValue);
    },
  );

  test('speed3 unlock gates the ×3 speed control (§8.4 #14)', () {
    final g = GameController(balance: balance, clock: FakeTickClock(), seed: 1);
    expect(g.speedX3Unlocked, isFalse);
    final s3 = balance.unlocks.firstWhere((u) => u.modType == 'speed3');
    g.meta.unlockLevels[s3.id] = 1; // arrange (full-tier → granted directly)
    expect(g.speedX3Unlocked, isTrue);
  });

  test('unlocks + soul points persist across a relaunch', () async {
    final tmp = Directory.systemTemp.createTempSync('isekai_meta');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final store = SaveStore(balance, tmp);

    final g1 = GameController(
      balance: balance,
      clock: FakeTickClock(),
      seed: 1,
      store: store,
    );
    g1.meta.soulPoints = 3000;
    final eq = balance.unlocks.firstWhere((u) => u.key == 'tool_memory');
    expect(g1.purchaseUnlock(eq.id), isTrue);
    await g1.persist();

    final restored = await store.load();
    final g2 = GameController(
      balance: balance,
      clock: FakeTickClock(),
      seed: 1,
      store: store,
      restored: restored,
    );
    expect(g2.meta.isUnlocked(eq.id), isTrue);
    expect(g2.soulPointsTotal, 3000 - eq.cost);
  });
}
