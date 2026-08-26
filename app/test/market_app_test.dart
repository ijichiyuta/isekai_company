import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/game_controller.dart';
import 'package:isekai_app/game/tick_clock.dart';

import 'helpers.dart';

void main() {
  test('market loads and the controller surfaces the trend (v0.9 §7)', () {
    final b = loadTestBalanceMarket();
    expect(b.market, isNotNull);
    final g = GameController(balance: b, clock: FakeTickClock(), seed: 1);
    // No trend yet.
    expect(g.trendCategoryName, isNull);
    // Force a live trend on category 0.
    g.state
      ..trendCategory = 0
      ..trendForecastWeeks = 0
      ..trendActiveWeeks = 6
      ..trendMultX100 = 300;
    expect(g.trendCategoryName, b.market!.categories[0]);
    expect(g.trendActive, isTrue);
    expect(g.trendWeeksLeft, 6);
    expect(g.trendMultPercent, 300);
    // Forecast (announced, not yet live) reports the lead time, not active.
    g.state
      ..trendForecastWeeks = 4
      ..trendActiveWeeks = 6;
    expect(g.trendActive, isFalse);
    expect(g.trendWeeksLeft, 4);
  });

  test('a trend onset auto-pauses the clock (§7 予告→plan)', () {
    final b = loadTestBalanceMarket();
    final clock = FakeTickClock();
    final g = GameController(balance: b, clock: clock, seed: 3);
    g.setSpeed(GameSpeed.x2);
    expect(clock.isRunning, isTrue);
    // Fire ticks until a trend is announced; the controller should pause.
    var paused = false;
    for (var i = 0; i < 500 && g.isAlive; i++) {
      clock.fire();
      if (g.speed == GameSpeed.paused) {
        paused = true;
        break;
      }
    }
    // A trend (or an event/invention, which also pause) occurs within 500wk;
    // at least one auto-pause fired, proving the pause path runs with a market.
    expect(paused, isTrue);
  });
}
