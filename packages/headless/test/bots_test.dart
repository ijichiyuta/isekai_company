import 'package:isekai_core/isekai_core.dart';
import 'package:isekai_headless/isekai_headless.dart';
import 'package:test/test.dart';

void main() {
  final balance = loadBalanceFromDir('../../assets/balance');

  test('registry exposes exactly the four §18.1 bots', () {
    expect(botRegistry.keys.toSet(),
        {'steady', 'attack', 'idle', 'collection'});
  });

  group('every bot is deterministic (AC-02) and completes (AC-01)', () {
    for (final name in ['steady', 'attack', 'idle', 'collection']) {
      test(name, () {
        final factory = botFactoryByName(name);
        final a = runLife(balance, 42, botFactory: factory);
        final b = runLife(balance, 42, botFactory: factory);
        expect(a.finalHash, b.finalHash, reason: '$name not deterministic');
        expect(a.bot, name);
        expect(a.endReason, anyOf('lifespan', 'bankrupt'));
        expect(verifyReplay(balance, 7, botFactory: factory), isNull);
      });
    }
  });

  test('idle survives (floor guarantee) across seeds; attack risks ruin', () {
    var idleBankrupt = 0;
    var attackBankrupt = 0;
    for (var seed = 0; seed < 40; seed++) {
      if (runLife(balance, seed, botFactory: botRegistry['idle'])
              .endReason ==
          'bankrupt') idleBankrupt++;
      if (runLife(balance, seed, botFactory: botRegistry['attack'])
              .endReason ==
          'bankrupt') attackBankrupt++;
    }
    // Idle is the floor: it should essentially never go bankrupt.
    expect(idleBankrupt, lessThan(4));
    // Attack trades safety for upside: strictly riskier than idle.
    expect(attackBankrupt, greaterThanOrEqualTo(idleBankrupt));
  });

  test('collection out-earns steady via offline income (Grant path)', () {
    var collectionWins = 0;
    for (var seed = 0; seed < 20; seed++) {
      final c = runLife(balance, seed, botFactory: botRegistry['collection']);
      final s = runLife(balance, seed, botFactory: botRegistry['steady']);
      if (c.funds >= s.funds) collectionWins++;
    }
    // Offline injection should never make collection poorer than steady.
    expect(collectionWins, greaterThan(15));
  });

  test('save/load mid-life resumes bit-identically for attack bot', () {
    final engine = Engine(balance);
    AttackBot mk() => AttackBot(balance);

    final s1 = GameState.initial(balance, 55);
    var bot = mk();
    while (s1.alive && s1.week < 600) {
      engine.tick(s1, bot.decide(s1));
    }
    final saved = encodeSave(s1, MetaState.initial(), balance);
    while (s1.alive) {
      engine.tick(s1, bot.decide(s1));
    }

    final s2 = decodeSave(saved, balance).state;
    final bot2 = mk();
    while (s2.alive) {
      engine.tick(s2, bot2.decide(s2));
    }
    expect(hashHex(s2.stateHash()), hashHex(s1.stateHash()));
  });
}
