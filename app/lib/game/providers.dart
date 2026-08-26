import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import 'balance_loader.dart';
import 'game_controller.dart';
import 'save_store.dart';
import 'tick_clock.dart';

/// Loads the bundled balance once. Overridable in tests.
final balanceProvider = FutureProvider<Balance>((ref) => loadBundledBalance());

/// The real-time clock. Tests override this with a [FakeTickClock].
final tickClockProvider = Provider<TickClock>((ref) => RealTickClock());

/// The save store, or null when persistence is unavailable (e.g. a widget test
/// without platform channels). Errors are swallowed so the game still runs
/// in-memory rather than failing to boot.
final saveStoreProvider = FutureProvider<SaveStore?>((ref) async {
  final balance = await ref.watch(balanceProvider.future);
  try {
    return await SaveStore.open(balance);
  } catch (_) {
    return null;
  }
});

/// The restored save (state + meta), or null on first run / corruption / no
/// store. Depended on by [_Bootstrap] so the controller sees it synchronously.
final restoredSaveProvider = FutureProvider<SaveData?>((ref) async {
  final store = await ref.watch(saveStoreProvider.future);
  if (store == null) return null;
  return store.load();
});

/// The live game. ChangeNotifierProvider disposes the returned controller
/// automatically (which stops its clock) — no explicit ref.onDispose, or the
/// controller would be disposed twice. Reads the loaded balance/store/save via
/// requireValue; [_Bootstrap] gates the UI until [restoredSaveProvider] (which
/// transitively awaits balance + store) resolves, so these never race.
final gameControllerProvider =
    ChangeNotifierProvider<GameController>((ref) {
  final balance = ref.watch(balanceProvider).requireValue;
  final store = ref.watch(saveStoreProvider).requireValue;
  final restored = ref.watch(restoredSaveProvider).requireValue;
  return GameController(
    balance: balance,
    clock: ref.watch(tickClockProvider),
    store: store,
    restored: restored,
  );
});
