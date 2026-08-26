import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/game_controller.dart';
import 'package:isekai_app/game/tick_clock.dart';
import 'package:isekai_core/isekai_core.dart';

import 'helpers.dart';

void main() {
  late Balance balance;
  setUpAll(() => balance = loadTestBalance());

  // Pudding = recipe 0: wheat(0) + egg(1) + cooling(method 0).
  void developPudding(GameController g) {
    g.reserve(OrderMaterial(0, 1));
    g.reserve(OrderMaterial(1, 1));
    g.reserve(Develop(0, 1, 0));
    g.step();
  }

  test('developing pudding discovers it and raises an invention event', () {
    final g = GameController(balance: balance, clock: FakeTickClock(), seed: 1);
    expect(g.state.discovered[0], isFalse);
    developPudding(g);
    expect(g.state.discovered[0], isTrue);
    expect(g.state.inventions, 1);
    final ev = g.pendingInvention;
    expect(ev, isNotNull);
    expect(ev!.name, 'プリン');
    expect(ev.fameBonus, greaterThan(0));
    g.acknowledgeInvention();
    expect(g.pendingInvention, isNull);
  });

  test('reservations apply on the next tick, then clear (§2.1 予約制)', () {
    final g = GameController(balance: balance, clock: FakeTickClock(), seed: 1);
    g.reserve(OrderMaterial(0, 3));
    expect(g.pending, hasLength(1));
    expect(g.state.materialStock[0], 0); // not applied yet
    g.step();
    expect(g.state.materialStock[0], 3);
    expect(g.pending, isEmpty);
  });

  test('the full loop grows funds: develop → produce → auto-sell', () {
    final g = GameController(balance: balance, clock: FakeTickClock(), seed: 1);
    developPudding(g);
    g.acknowledgeInvention();
    final clock = g.clock as FakeTickClock;
    g.setSpeed(GameSpeed.x1); // starts the (fake) clock
    expect(clock.isRunning, isTrue);
    // Keep producing pudding each week while the clock ticks.
    var grewOnce = false;
    var prev = g.state.funds;
    for (var i = 0; i < 30; i++) {
      g.reserve(OrderMaterial(0, 2));
      g.reserve(OrderMaterial(1, 2));
      g.reserve(Produce(0, 2));
      clock.fire();
      if (g.state.funds > prev) grewOnce = true;
      prev = g.state.funds;
    }
    expect(grewOnce, isTrue, reason: 'sales should increase funds some weeks');
  });

  test('speed control drives / stops the clock; pauseForScreen stops it', () {
    final clock = FakeTickClock();
    final g = GameController(balance: balance, clock: clock, seed: 1);
    g.setSpeed(GameSpeed.x2);
    expect(clock.isRunning, isTrue);
    final w0 = g.state.week;
    clock.fire(3);
    expect(g.state.week, w0 + 3);
    g.pauseForScreen();
    expect(clock.isRunning, isFalse);
    clock.fire(3); // stopped clock does nothing
    expect(g.state.week, w0 + 3);
  });

  test('clock stops automatically when the life ends', () {
    final clock = FakeTickClock();
    final g = GameController(balance: balance, clock: clock, seed: 1);
    g.setSpeed(GameSpeed.x3);
    // Fire well past the 2880-week lifespan.
    clock.fire(3000);
    expect(g.isAlive, isFalse);
    expect(clock.isRunning, isFalse);
    expect(g.state.week, lessThanOrEqualTo(balance.economy.lifespanWeeks));
  });

  test('life end computes a lifetime score (§8.2)', () {
    final g = GameController(balance: balance, clock: FakeTickClock(), seed: 1);
    expect(g.lifeScore, isNull);
    g.retire();
    expect(g.isAlive, isFalse);
    expect(g.lifeScore, isNotNull);
    expect(g.lifeScore!.total, greaterThanOrEqualTo(0));
    expect(g.pendingSoulPoints, greaterThanOrEqualTo(0));
  });

  test('pending event surfaces and a choice applies + clears it (§3.7)', () {
    final eb = loadTestBalanceWithEvents();
    final g = GameController(balance: eb, clock: FakeTickClock(), seed: 1);
    // Force the royal event pending (id 0) and choose to accept it.
    g.state.pendingEventId = 0;
    expect(g.pendingEvent, isNotNull);
    expect(g.pendingEvent!.id, 0);
    g.chooseEvent(0); // accept → royal_flag + funds
    expect(g.state.royalCleared, isTrue);
    expect(g.pendingEvent, isNull); // resolved
  });

  test('rebirth banks soul points and starts a fresh, later life', () {
    final g = GameController(balance: balance, clock: FakeTickClock(), seed: 1);
    // Develop pudding so the finished life has a non-zero score.
    developPudding(g);
    g.acknowledgeInvention();
    g.retire();
    final earned = g.pendingSoulPoints;
    expect(g.lifeNumber, 1);

    g.rebirth();
    expect(g.lifeNumber, 2);
    expect(g.soulPointsTotal, earned);
    expect(g.isAlive, isTrue);
    expect(g.state.week, 0);
    expect(g.state.discoveries, 0); // fresh life
    expect(g.lifeScore, isNull);
    // lifeNumber must be threaded into the new GameState so cycle events work
    // (audit D-2 fix).
    expect(g.state.lifeNumber, 2);
  });
}
