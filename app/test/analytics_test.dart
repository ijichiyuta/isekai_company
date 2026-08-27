import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/analytics.dart';
import 'package:isekai_app/game/game_controller.dart';
import 'package:isekai_app/game/iap_stub.dart';
import 'package:isekai_app/game/tick_clock.dart';
import 'package:isekai_core/isekai_core.dart';

import 'helpers.dart';

class _Capture implements AnalyticsClient {
  final events = <String>[];
  @override
  void event(String name, [Map<String, Object?> params = const {}]) =>
      events.add(name);
}

class _OkIap implements IapClient {
  @override
  bool get available => true;
  @override
  Future<bool> purchaseFull() async => true;
  @override
  Future<bool> restore() async => true;
}

void main() {
  test('funnel events are emitted at the key touchpoints (§24 分析)', () async {
    final a = _Capture();
    final b = loadTestBalanceFull();
    final g = GameController(
      balance: b,
      clock: FakeTickClock(),
      seed: 1,
      iap: _OkIap(),
      analytics: a,
    );
    g.completeTutorial();
    // Buy a functional free unlock → unlock_bought.
    g.meta.soulPoints = 9000;
    final freeFn = b.unlocks.firstWhere(
      (u) => u.tier == 'free' && isUnlockFunctional(u),
    );
    g.purchaseUnlock(freeFn.id);
    await g.purchaseFull(); // purchase_full
    await g
        .restorePurchases(); // restore (already full → no re-emit; force via fresh)
    g.retire(); // life_end
    g.rebirth(); // rebirth
    expect(
      a.events,
      containsAll(<String>[
        AnalyticsEvents.tutorialDone,
        AnalyticsEvents.unlockBought,
        AnalyticsEvents.purchaseFull,
        AnalyticsEvents.lifeEnd,
        AnalyticsEvents.rebirth,
      ]),
    );
  });

  test('restore emits its funnel event', () async {
    final a = _Capture();
    final g = GameController(
      balance: loadTestBalanceFull(),
      clock: FakeTickClock(),
      seed: 1,
      iap: _OkIap(),
      analytics: a,
    );
    expect(await g.restorePurchases(), isTrue);
    expect(a.events, contains(AnalyticsEvents.restore));
  });
}
