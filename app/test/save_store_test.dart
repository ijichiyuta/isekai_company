import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/game_controller.dart';
import 'package:isekai_app/game/save_store.dart';
import 'package:isekai_app/game/tick_clock.dart';
import 'package:isekai_core/isekai_core.dart';

import 'helpers.dart';

MetaState _meta(int soulPoints, {bool tutorial = false}) => MetaState.raw(
  soulPoints: soulPoints,
  lifetimeBest: 0,
  tutorialDone: tutorial,
  unlockLevels: <int>[],
);

void main() {
  late Balance balance;
  late Directory tmp;
  setUpAll(() => balance = loadTestBalance());
  setUp(() => tmp = Directory.systemTemp.createTempSync('isekai_save'));
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('save then load round-trips state + meta', () async {
    final store = SaveStore(balance, tmp);
    final s = GameState.initial(balance, 7);
    Engine(balance).tick(s, [OrderMaterial(0, 1)]);
    await store.save(s, _meta(33, tutorial: true));

    final restored = await store.load();
    expect(restored, isNotNull);
    expect(restored!.state.stateHash(), s.stateHash());
    expect(restored.meta.soulPoints, 33);
    expect(restored.meta.tutorialDone, isTrue);
  });

  test('load returns null on first run (no save files)', () async {
    expect(await SaveStore(balance, tmp).load(), isNull);
  });

  test('keeps 3 generations and loads the newest', () async {
    final store = SaveStore(balance, tmp);
    for (var sp = 1; sp <= 5; sp++) {
      await store.save(GameState.initial(balance, sp), _meta(sp));
    }
    final restored = await store.load();
    expect(restored!.meta.soulPoints, 5); // newest

    final saves = tmp
        .listSync()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    expect(saves.length, SaveStore.generations); // exactly 3 kept
  });

  test(
    'falls back to an older generation when the newest is corrupt',
    () async {
      final store = SaveStore(balance, tmp);
      await store.save(GameState.initial(balance, 1), _meta(10));
      await store.save(GameState.initial(balance, 2), _meta(20));
      // Corrupt the newest generation (save.0).
      File('${tmp.path}/save.0.json').writeAsStringSync('{"garbage":true}');

      final restored = await store.load();
      expect(restored!.meta.soulPoints, 10); // fell back to save.1
    },
  );

  test('progress persists across a controller relaunch (P0 / C-6)', () async {
    final store = SaveStore(balance, tmp);
    final g1 = GameController(
      balance: balance,
      clock: FakeTickClock(),
      seed: 1,
      store: store,
    );
    g1.completeTutorial();
    g1.retire();
    final earned = g1.pendingSoulPoints;
    g1.rebirth();
    await g1.persist(); // flush all queued fire-and-forget saves

    // Relaunch: load the save and rebuild a fresh controller from it.
    final restored = await store.load();
    final g2 = GameController(
      balance: balance,
      clock: FakeTickClock(),
      seed: 1,
      store: store,
      restored: restored,
    );

    expect(g2.soulPointsTotal, earned); // soul points survived
    expect(g2.tutorialDone, isTrue); // onboarding won't replay (§C-6)
    expect(g2.lifeNumber, 2); // resumed on the 2nd life
    expect(g2.isAlive, isTrue);
  });
}
