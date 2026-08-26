import 'package:flutter/foundation.dart';
import 'package:isekai_core/isekai_core.dart';

import 'tick_clock.dart';

enum GameSpeed { paused, x1, x2, x3 }

extension GameSpeedX on GameSpeed {
  /// Real time per in-game week (requirements §2.1: ×1 = 1.5s/tick).
  Duration? get interval => switch (this) {
        GameSpeed.paused => null,
        GameSpeed.x1 => const Duration(milliseconds: 1500),
        GameSpeed.x2 => const Duration(milliseconds: 750),
        GameSpeed.x3 => const Duration(milliseconds: 500),
      };
  String get label => switch (this) {
        GameSpeed.paused => 'II',
        GameSpeed.x1 => '×1',
        GameSpeed.x2 => '×2',
        GameSpeed.x3 => '×3',
      };
}

/// A discovery that just happened, surfaced to the UI so it can play the
/// invention overlay (§12.5) — the emotional peak of the loop.
class InventionEvent {
  final int recipeId;
  final String name;
  final int cashBonus;
  final int fameBonus;
  const InventionEvent(this.recipeId, this.name, this.cashBonus, this.fameBonus);
}

/// The whole app-facing game state. Owns the deterministic [GameState] and the
/// real-time clock; UI reads via [ChangeNotifier]. All player actions are
/// RESERVATIONS applied on the next tick (§2.1 予約制) — no APM required.
class GameController extends ChangeNotifier {
  final Balance balance;
  final Engine engine;
  final TickClock clock;

  late GameState _state;
  final List<Command> _pending = [];
  GameSpeed _speed = GameSpeed.paused;
  final List<InventionEvent> _inventionQueue = [];

  GameController({required this.balance, required this.clock, int seed = 1})
      : engine = Engine(balance) {
    _state = GameState.initial(balance, seed);
  }

  GameState get state => _state;
  GameSpeed get speed => _speed;
  List<Command> get pending => List.unmodifiable(_pending);
  InventionEvent? get pendingInvention =>
      _inventionQueue.isEmpty ? null : _inventionQueue.first;
  bool get isAlive => _state.alive;

  /// Last week's sales, surfaced so the loop's "profit" node is visible (§3.1).
  int lastWeekRevenue = 0;
  int lastWeekSold = 0;
  bool lastRankedUp = false;

  RecipeDef? recipeById(int id) =>
      id >= 0 && id < balance.recipes.length ? balance.recipes[id] : null;

  /// Reserve a command for the next tick.
  void reserve(Command c) {
    _pending.add(c);
    notifyListeners();
  }

  void clearReservations() {
    _pending.clear();
    notifyListeners();
  }

  void setSpeed(GameSpeed s) {
    _speed = s;
    final interval = s.interval;
    if (interval == null || !_state.alive) {
      clock.stop();
    } else {
      clock.start(interval, _onClockTick);
    }
    notifyListeners();
  }

  /// Auto-pause helper for management screens (§2.1, §12.1): they must not let
  /// the clock run underneath the player.
  void pauseForScreen() {
    if (_speed != GameSpeed.paused) setSpeed(GameSpeed.paused);
  }

  void _onClockTick() {
    step();
    if (!_state.alive) clock.stop();
  }

  /// Apply all reserved commands and advance exactly one week. Also usable for
  /// immediate feedback (e.g. confirming a development while paused) and by the
  /// debug menu / tests.
  void step() {
    if (!_state.alive) return;
    final result = engine.tick(_state, List<Command>.of(_pending));
    _pending.clear();

    lastWeekRevenue = result.weeklyRevenue;
    lastWeekSold = result.weeklySold;
    lastRankedUp = result.rankedUp;

    // Exact invention bonuses come from the engine now (no funds-delta guess).
    // Queue them so simultaneous inventions each get their moment (§12.5).
    if (result.inventions.isNotEmpty) {
      for (final inv in result.inventions) {
        _inventionQueue.add(InventionEvent(
          inv.recipeId,
          balance.recipes[inv.recipeId].name,
          inv.cashBonus,
          inv.fameBonus,
        ));
      }
      // Auto-pause so the overlay isn't undercut by a running clock (§12.5).
      _speed = GameSpeed.paused;
      clock.stop();
    }
    notifyListeners();
  }

  /// Called by the UI after each invention overlay is dismissed.
  void acknowledgeInvention() {
    if (_inventionQueue.isNotEmpty) _inventionQueue.removeAt(0);
    notifyListeners();
  }

  /// Debug helpers (requirements §10.6). Excluded from release by the caller
  /// (kDebugMode gate → AC-14).
  void debugGrant(int amount) {
    assert(kDebugMode);
    reserve(Grant(amount, 'debug'));
    step();
  }

  void debugStep([int n = 1]) {
    assert(kDebugMode);
    for (var i = 0; i < n; i++) {
      step();
    }
  }

  @override
  void dispose() {
    clock.stop();
    super.dispose();
  }
}
