import 'package:isekai_core/isekai_core.dart';
import 'package:isekai_headless/isekai_headless.dart';
import 'package:test/test.dart';

void main() {
  final balance = loadBalanceFromDir('../../assets/balance');

  test('full life: same seed twice → identical final hash (AC-02)', () {
    final a = runLife(balance, 42);
    final b = runLife(balance, 42);
    expect(a.finalHash, b.finalHash);
    expect(a.weeks, b.weeks);
    expect(a.funds, b.funds);
  });

  test('events-loaded life is deterministic (same seed twice)', () {
    final eb = loadBalanceFromDir('../../assets/balance', withEvents: true);
    expect(eb.events, isNotEmpty);
    String run() {
      final s = GameState.initial(eb, 42);
      final engine = Engine(eb);
      final bot = SteadyBot(eb);
      while (s.alive) {
        engine.tick(s, bot.decide(s));
      }
      return hashHex(s.stateHash());
    }

    expect(run(), run());
  });

  test('different seeds diverge', () {
    final a = runLife(balance, 1);
    final b = runLife(balance, 2);
    expect(a.finalHash, isNot(b.finalHash));
  });

  test('checkpointed replay matches (AC-02)', () {
    expect(verifyReplay(balance, 7), isNull);
  });

  test('save/load mid-life resumes bit-identically', () {
    final engine = Engine(balance);
    final bot = SteadyBot(balance);

    // Uninterrupted run.
    final s1 = GameState.initial(balance, 123);
    while (s1.alive && s1.week < 700) {
      engine.tick(s1, bot.decide(s1));
    }
    final savedAt700 = encodeSave(s1, MetaState.initial(), balance);
    while (s1.alive) {
      engine.tick(s1, bot.decide(s1));
    }

    // Resume from the mid-life save with a fresh bot instance.
    final s2 = decodeSave(savedAt700, balance).state;
    final bot2 = SteadyBot(balance);
    while (s2.alive) {
      engine.tick(s2, bot2.decide(s2));
    }

    expect(hashHex(s2.stateHash()), hashHex(s1.stateHash()));
  });

  test('life 1 cannot discover band-2 recipes (free-range boundary)', () {
    final stats = runLife(balance, 5);
    final band1Count =
        balance.recipes.where((r) => r.band == 1).length;
    expect(stats.discoveries, lessThanOrEqualTo(band1Count));
  });

  test('life completes without crash for 20 seeds', () {
    for (var seed = 100; seed < 120; seed++) {
      final stats = runLife(balance, seed);
      expect(stats.endReason, anyOf('lifespan', 'bankrupt'));
    }
  });
}
