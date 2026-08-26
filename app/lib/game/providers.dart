import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import 'balance_loader.dart';
import 'game_controller.dart';
import 'tick_clock.dart';

/// Loads the bundled balance once. Overridable in tests.
final balanceProvider = FutureProvider<Balance>((ref) => loadBundledBalance());

/// The real-time clock. Tests override this with a [FakeTickClock].
final tickClockProvider = Provider<TickClock>((ref) => RealTickClock());

/// The live game. Depends on a loaded balance. ChangeNotifierProvider disposes
/// the returned controller automatically (which stops its clock) — no explicit
/// ref.onDispose, or the controller would be disposed twice.
final gameControllerProvider =
    ChangeNotifierProvider<GameController>((ref) {
  final balance = ref.watch(balanceProvider).requireValue;
  return GameController(balance: balance, clock: ref.watch(tickClockProvider));
});
