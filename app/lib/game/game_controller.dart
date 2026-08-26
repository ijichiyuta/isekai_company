import 'package:flutter/foundation.dart';
import 'package:isekai_core/isekai_core.dart';

import 'analytics.dart';
import 'entitlements.dart';
import 'iap_stub.dart';
import 'save_store.dart';
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
  const InventionEvent(
    this.recipeId,
    this.name,
    this.cashBonus,
    this.fameBonus,
  );
}

/// The whole app-facing game state. Owns the deterministic [GameState] and the
/// real-time clock; UI reads via [ChangeNotifier]. All player actions are
/// RESERVATIONS applied on the next tick (§2.1 予約制) — no APM required.
class GameController extends ChangeNotifier {
  final Balance balance;
  final Engine engine;
  final TickClock clock;

  late GameState _state;
  late MetaState _meta;
  final SaveStore? _store;
  final Entitlements _entitlements;
  final IapClient _iap;
  final AnalyticsClient _analytics;
  final List<Command> _pending = [];
  GameSpeed _speed = GameSpeed.paused;
  final List<InventionEvent> _inventionQueue = [];
  final int _baseSeed;
  final ScoreParams _scoreParams = ScoreParams.defaults();

  /// [restored] resumes a saved game (state + cross-life meta); null starts a
  /// fresh life. [store] persists progress at life-end / rebirth / tutorial /
  /// background — null disables persistence (unit tests without a filesystem).
  GameController({
    required this.balance,
    required this.clock,
    int seed = 1,
    SaveStore? store,
    SaveData? restored,
    Entitlements? entitlements,
    IapClient? iap,
    AnalyticsClient? analytics,
  }) : _baseSeed = seed,
       _store = store,
       _entitlements = entitlements ?? Entitlements(),
       _iap = iap ?? StubIapClient(),
       _analytics = analytics ?? const NoopAnalytics(),
       engine = Engine(balance) {
    if (restored != null) {
      _state = restored.state; // meta already baked into the saved state
      _meta = restored.meta;
      lifeNumber = _state.lifeNumber;
      // A restored save whose life already ended shows the result screen.
      if (!_state.alive) {
        _lifeScore = computeLifetimeScore(_state, balance, _scoreParams);
      }
    } else {
      _meta = MetaState.initial();
      _state = GameState.fromMeta(balance, seed, _meta); // fresh: meta = none
    }
    _meta.ensureUnlockSlots(balance.unlocks.length);
  }

  GameState get state => _state;
  MetaState get meta => _meta;

  /// Read-only meta progression for the paywall / tree UI (P3), decoupled from
  /// MetaState's storage.
  MetaReader get metaReader => MetaView(_meta, balance.unlocks);

  // --- Season / trend (v0.9 §6/§7) ---
  /// Current trending category name, or null when no trend is running/announced.
  String? get trendCategoryName {
    final m = balance.market;
    final c = _state.trendCategory;
    return (m != null && c >= 0 && c < m.categories.length)
        ? m.categories[c]
        : null;
  }

  /// A trend is live (multiplier applied) vs merely announced (forecast).
  bool get trendActive =>
      _state.trendActiveWeeks > 0 && _state.trendForecastWeeks == 0;

  /// Weeks until a forecast trend starts, or weeks a live trend has left.
  int get trendWeeksLeft =>
      trendActive ? _state.trendActiveWeeks : _state.trendForecastWeeks;

  int get trendMultPercent => _state.trendMultX100;

  /// ×3 speed is unlocked by 時の加速 (§8.4 #14). Until then the speed control
  /// tops out at ×2 (the tree UI + paywall surface the upgrade).
  bool get speedX3Unlocked => balance.unlocks.any(
    (u) => u.modType == 'speed3' && _meta.isUnlocked(u.id),
  );

  // --- Monetization (P3) ---
  bool get isFull => _entitlements.isFull;
  bool get iapAvailable => _iap.available;

  /// Dynamic unlock accounting for the paywall / tree (AC-16 — from balance).
  UnlockSummary get unlockSummary => UnlockSummary.compute(metaReader);

  /// Buy 完全版 through the IAP client. On success flips the entitlement and
  /// persists it (separate file — survives balance changes). Returns success.
  Future<bool> purchaseFull() async {
    if (_entitlements.isFull) return true;
    final ok = await _iap.purchaseFull();
    if (ok) {
      _entitlements.isFull = true;
      _analytics.event(AnalyticsEvents.purchaseFull);
      await _store?.saveEntitlements(_entitlements);
      notifyListeners();
    }
    return ok;
  }

  /// Restore a prior 完全版 purchase (App Store 3.1.1 / §14.4). Returns whether
  /// a purchase was restored.
  Future<bool> restorePurchases() async {
    final ok = await _iap.restore();
    if (ok && !_entitlements.isFull) {
      _entitlements.isFull = true;
      _analytics.event(AnalyticsEvents.restore);
      await _store?.saveEntitlements(_entitlements);
      notifyListeners();
    }
    return ok;
  }

  GameSpeed get speed => _speed;
  List<Command> get pending => List.unmodifiable(_pending);
  InventionEvent? get pendingInvention =>
      _inventionQueue.isEmpty ? null : _inventionQueue.first;
  bool get isAlive => _state.alive;

  /// Last week's sales, surfaced so the loop's "profit" node is visible (§3.1).
  int lastWeekRevenue = 0;
  int lastWeekSold = 0;
  bool lastRankedUp = false;

  // --- Second-layer loop: life evaluation & rebirth (§8, requirements §24) ---
  int lifeNumber = 1;

  /// Banked soul points across all lives — the single source of truth is [meta]
  /// (persisted). Cumulative, carried in full between lives (§8.4).
  int get soulPointsTotal => _meta.soulPoints;

  /// Whether the first-run tutorial has been completed (persisted, §C-6). A
  /// restored save with this set skips onboarding on 2周目 / relaunch.
  bool get tutorialDone => _meta.tutorialDone;

  LifetimeScore? _lifeScore;

  /// The finished life's score, available once the life has ended.
  LifetimeScore? get lifeScore => _lifeScore;

  /// The event awaiting the player's choice, or null (§3.7).
  EventDef? get pendingEvent {
    final id = _state.pendingEventId;
    return id >= 0 && id < balance.events.length ? balance.events[id] : null;
  }

  /// Resolve the pending event by choice, then advance one week to apply it.
  void chooseEvent(int choiceIndex) {
    final id = _state.pendingEventId;
    if (id < 0) return;
    reserve(ChooseEvent(id, choiceIndex));
    step();
  }

  /// Soul-memory points this finished life is worth (§8.2/§8.4).
  int get pendingSoulPoints => _lifeScore == null
      ? 0
      : soulPointsFromScore(_lifeScore!.total, _scoreParams);

  /// End the life immediately by choice (引退, §8.1). The early-retire penalty
  /// modelling lands in M2 balance; for now retirement just closes the life.
  void retire() {
    if (!_state.alive) return;
    _state.alive = false;
    _state.endReason = 'retire';
    _onLifeEnded();
    notifyListeners();
  }

  /// Start the next life (転生). Accumulates soul points; the soul-memory tree
  /// and meta persistence are M3 — for now it just banks points and resets.
  void rebirth() {
    if (_state.alive) return;
    _meta.soulPoints += pendingSoulPoints;
    lifeNumber++;
    _lifeScore = null;
    _inventionQueue.clear();
    _pending.clear();
    lastWeekRevenue = 0;
    lastWeekSold = 0;
    lastRankedUp = false;
    _speed = GameSpeed.paused;
    clock.stop();
    // Auto-tier unlocks (§8.4 #3) are granted on rebirth from a completed life.
    _grantAutoUnlocks();
    // A fresh, deterministic seed per life, with 魂の記憶 applied as start-state
    // bonuses (§8.4 — this is what shortens 2周目, C-6). lifeNumber threads into
    // the state so cycle events (min_life >= 2) can fire on later lives (§3.7).
    _state = GameState.fromMeta(
      balance,
      _baseSeed + lifeNumber,
      _meta,
      lifeNumber: lifeNumber,
    );
    _analytics.event(AnalyticsEvents.rebirth, {'life': lifeNumber});
    _persist(); // bank the new soul points + fresh life
    notifyListeners();
  }

  /// Grant every not-yet-owned 'auto' tier unlock (non-paid, condition-met on
  /// completing a life — §8.4 #3 開始ランク露店).
  void _grantAutoUnlocks() {
    _meta.ensureUnlockSlots(balance.unlocks.length);
    for (final u in balance.unlocks) {
      if (u.tier == 'auto' && !_meta.isUnlocked(u.id)) {
        _meta.unlockLevels[u.id] = 1;
      }
    }
  }

  /// Buy the next level of soul-memory unlock [id] (§8.4). Enforces the 完全版
  /// tier gate (P3 — 'full' nodes need the purchase; free/auto never gated,
  /// so #16 自動発注 is always buyable) then prerequisites + affordability +
  /// one-shot/infinite in core. Returns true on purchase, and persists.
  bool purchaseUnlock(int id) {
    if (id < 0 || id >= balance.unlocks.length) return false;
    if (!_entitlements.canPurchase(balance.unlocks[id])) {
      return false; // paywall
    }
    if (!tryPurchaseUnlock(_meta, balance.unlocks, id)) return false;
    _analytics.event(AnalyticsEvents.unlockBought, {
      'id': id,
      'key': balance.unlocks[id].key,
    });
    _persist();
    notifyListeners();
    return true;
  }

  void _onLifeEnded() {
    _lifeScore ??= computeLifetimeScore(_state, balance, _scoreParams);
    if (_lifeScore!.total > _meta.lifetimeBest) {
      _meta.lifetimeBest = _lifeScore!.total;
    }
    _speed = GameSpeed.paused;
    clock.stop();
    _analytics.event(AnalyticsEvents.lifeEnd, {
      'life': lifeNumber,
      'reason': _state.endReason,
      'rank': _state.rank,
      'score': _lifeScore!.total,
    });
    _persist(); // the ended life is worth saving (resume shows the result)
  }

  /// Mark the first-run tutorial done and persist it (§C-6 — 2周目 skips it).
  void completeTutorial() {
    if (_meta.tutorialDone) return;
    _meta.tutorialDone = true;
    _analytics.event(AnalyticsEvents.tutorialDone);
    _persist();
    notifyListeners();
  }

  /// Fire-and-forget persistence at discrete milestones (life-end, rebirth,
  /// tutorial). No-op when [_store] is null (tests).
  void _persist() {
    _store?.save(_state, _meta);
  }

  /// Awaitable persistence for the app-lifecycle observer (save on background).
  Future<void> persist() async {
    await _store?.save(_state, _meta);
  }

  RecipeDef? recipeById(int id) =>
      id >= 0 && id < balance.recipes.length ? balance.recipes[id] : null;

  // --- Reinvestment drivers (§10.2): player-facing equipment / quality. The
  // upgrade commands apply on the next tick (予約制); costs mirror the engine's
  // geometric curve so the button label matches what will be charged. ---
  int get equipmentLevel => _state.equipmentLevel;
  int get qualityStar => _state.qualityStar;
  int get equipMaxLevel => balance.economy.equipMaxLevel;
  int get qualityMaxStar => balance.economy.qualityMultX100.length - 1;
  bool get canUpgradeEquipment => _state.equipmentLevel < equipMaxLevel;
  bool get canUpgradeQuality => _state.qualityStar < qualityMaxStar;

  /// Weekly production capacity WITH the equipment multiplier (matches engine).
  int get weeklyCapacity {
    final eco = balance.economy;
    final base =
        eco.baseCapacityPerWeek + _state.employees * eco.artisanOutputPerWeek;
    var cap = base * (100 + _state.equipmentLevel * eco.equipStepX100) ~/ 100;
    if (_state.productionBonusX100 != 0) {
      cap = cap * (100 + _state.productionBonusX100) ~/ 100;
    }
    return cap;
  }

  /// Current sale-price multiplier from quality, in percent (100 = base).
  int get qualityMultPercent =>
      balance.economy.qualityMultX100[_state.qualityStar];

  int equipUpgradeCost() {
    final eco = balance.economy;
    var c = eco.equipCostBase;
    for (var i = 0; i < _state.equipmentLevel; i++) {
      c = c * eco.equipCostMultX100 ~/ 100;
    }
    return c;
  }

  int qualityUpgradeCost() {
    final eco = balance.economy;
    var c = eco.qualityCostBase;
    for (var i = 0; i < _state.qualityStar; i++) {
      c = c * eco.qualityCostMultX100 ~/ 100;
    }
    return c;
  }

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
        _inventionQueue.add(
          InventionEvent(
            inv.recipeId,
            balance.recipes[inv.recipeId].name,
            inv.cashBonus,
            inv.fameBonus,
          ),
        );
      }
      // Auto-pause so the overlay isn't undercut by a running clock (§12.5).
      _speed = GameSpeed.paused;
      clock.stop();
    }

    // An event needs a decision → auto-pause and let the UI show the dialog
    // (§3.7 / §12.1). Inventions take priority (shown first).
    if (result.firedEventId >= 0) {
      _speed = GameSpeed.paused;
      clock.stop();
    }

    // A trend was just announced (§7 予告): auto-pause so the player can plan —
    // produce the trending category to capitalize on the ×2-3 demand.
    if (result.trendOnset) {
      _speed = GameSpeed.paused;
      clock.stop();
    }

    // Life ended this tick (lifespan/bankruptcy) → compute the score once.
    if (!_state.alive) _onLifeEnded();
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
