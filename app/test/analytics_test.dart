import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/analytics.dart';
import 'package:isekai_app/game/game_controller.dart';
import 'package:isekai_app/game/tick_clock.dart';

import 'helpers.dart';

class _Capture implements AnalyticsClient {
  final events = <String>[];
  @override
  void event(String name, [Map<String, Object?> params = const {}]) =>
      events.add(name);
}

void main() {
  test('funnel events are emitted at the key touchpoints (§24 分析)', () {
    final a = _Capture();
    final g = GameController(
        balance: loadTestBalanceFull(),
        clock: FakeTickClock(),
        seed: 1,
        analytics: a);
    g.completeTutorial();
    g.retire();
    g.rebirth();
    expect(
        a.events,
        containsAll(<String>[
          AnalyticsEvents.tutorialDone,
          AnalyticsEvents.lifeEnd,
          AnalyticsEvents.rebirth,
        ]));
  });
}
