/// Cross-life meta progression (魂の記憶, requirements §8.4). Persists across
/// rebirths; the per-life [GameState] resets each cycle. Pure Dart — same
/// determinism rules as the rest of core (no dart:io/dart:math/double/HashMap,
/// §2.2, enforced by tool/check_forbidden.sh).
///
/// M3 layering: P0 introduces this skeleton + save persistence; P2 layers the
/// unlock tree (assets/balance/unlocks.json, UnlockDef, GameState.fromMeta
/// modifiers) on top — this schema is forward-compatible so P2 only adds
/// semantics, not fields.
library;

class MetaState {
  /// Unspent soul points (§8.4 — carried over in full between lives).
  int soulPoints;

  /// Best lifetime score so far (meta HUD / paywall context).
  int lifetimeBest;

  /// First-run tutorial finished — so 2周目 skips the guided onboarding (C-6).
  bool tutorialDone;

  /// Purchase level per unlock id: 0 = not owned, 1 = owned, >1 only for the
  /// infinite nodes (§8.4 items #21/#22 = unlocks.json ids 22/23, `1000×1.6^n`).
  /// Indexed by unlock id — a List
  /// (no HashMap in core, §2.2). Sized/padded to balance.unlocks.length by P2;
  /// empty in P0 (no unlock tree yet). A shorter-than-current list just means
  /// newer unlocks default to level 0 (graceful for unlocks.json growth).
  final List<int> unlockLevels;

  MetaState.raw({
    required this.soulPoints,
    required this.lifetimeBest,
    required this.tutorialDone,
    required this.unlockLevels,
  });

  factory MetaState.initial() => MetaState.raw(
        soulPoints: 0,
        lifetimeBest: 0,
        tutorialDone: false,
        unlockLevels: <int>[],
      );

  /// Times unlock [id] has been purchased (0 if none / out of range).
  int levelOf(int id) =>
      id >= 0 && id < unlockLevels.length ? unlockLevels[id] : 0;

  bool isUnlocked(int id) => levelOf(id) > 0;

  Map<String, dynamic> toJson() => {
        'soul_points': soulPoints,
        'lifetime_best': lifetimeBest,
        // Emit only when non-default so a fresh meta stays compact and stable.
        if (tutorialDone) 'tutorial_done': true,
        if (unlockLevels.any((l) => l != 0))
          'unlock_levels': List<int>.of(unlockLevels),
      };

  factory MetaState.fromJson(Map<String, dynamic> m) => MetaState.raw(
        soulPoints: (m['soul_points'] as int?) ?? 0,
        lifetimeBest: (m['lifetime_best'] as int?) ?? 0,
        tutorialDone: (m['tutorial_done'] as bool?) ?? false,
        unlockLevels:
            ((m['unlock_levels'] as List?)?.cast<int>().toList()) ?? <int>[],
      );

  /// Grow [unlockLevels] to at least [n] slots (zero-filled) so a node id can be
  /// indexed safely. Called after load with balance.unlocks.length so newer
  /// unlocks default to level 0 (graceful when unlocks.json grows).
  void ensureUnlockSlots(int n) {
    while (unlockLevels.length < n) {
      unlockLevels.add(0);
    }
  }
}

/// One node in the 魂の記憶 tree (§8.4), loaded from assets/balance/unlocks.json.
/// [tier] is one of 'free' (buy with soul points), 'full' (完全版 gated — P3
/// paywall), 'auto' (granted automatically, non-paid, e.g. #3 開始ランク).
/// [infinite] nodes (§8.4 items #21/#22 = ids 22/23) can be bought repeatedly;
/// their cost grows
/// geometrically ([unlockCostForLevel]).
class UnlockDef {
  final int id;
  final String key;
  final String name;
  final String desc;
  final int cost; // base cost (one-shot cost, or level-0 cost for infinite)
  final String tier;
  final List<int> requires;
  final String modType;
  final int modValue;
  final bool infinite;
  const UnlockDef({
    required this.id,
    required this.key,
    required this.name,
    required this.desc,
    required this.cost,
    required this.tier,
    required this.requires,
    required this.modType,
    required this.modValue,
    required this.infinite,
  });
}

/// Mod types that actually affect the game today — GameState.fromMeta applies
/// them (start bonuses + the per-life economy multipliers). Every other mod
/// type is FEATURE-GATED: its unlock can't be bought until the feature ships
/// (races, trends, decay, offline, auto-play, ×3 speed, hard mode, hint/reveal).
/// The tree UI marks those 今後有効化 and disables purchase, so the player never
/// spends points on a no-op and the paywall never over-promises (景表法).
const Set<String> functionalModTypes = {
  'start_funds',
  'start_employee',
  'start_rank',
  'equip_start_level',
  'quality_start_star',
  'start_funds_pct',
  'production_bonus',
  'sales_bonus',
  'order_discount',
  'grant_recipes', // pre-discovers staple recipes at life start (fromMeta)
  'speed3', // unlocks the ×3 speed control (app-level effect)
};

/// Whether [u]'s effect is wired into the simulation today (see
/// [functionalModTypes]).
bool isUnlockFunctional(UnlockDef u) => functionalModTypes.contains(u.modType);

/// Cost growth of an infinite node per already-owned level (§8.4: 1000×1.6^n).
const int _infiniteCostMultX100 = 160;

/// Soul-point cost to buy the NEXT level of [u] given the current [level].
/// One-shot nodes cost [UnlockDef.cost]; infinite nodes grow ×1.6 per level.
int unlockCostForLevel(UnlockDef u, int level) {
  if (!u.infinite) return u.cost;
  var c = u.cost;
  for (var i = 0; i < level; i++) {
    c = c * _infiniteCostMultX100 ~/ 100;
  }
  return c;
}

/// Attempt to buy the next level of unlock [id] from [meta], spending soul
/// points. Enforces prerequisites (all [requires] owned), affordability, and
/// one-shot-vs-infinite. Does NOT check tier/entitlement — the completion-tier
/// paywall lives in the app layer (P3). Returns true iff a purchase happened.
bool tryPurchaseUnlock(MetaState meta, List<UnlockDef> unlocks, int id) {
  if (id < 0 || id >= unlocks.length) return false;
  final u = unlocks[id];
  if (!isUnlockFunctional(u)) return false; // feature not shipped yet (景表法)
  final level = meta.levelOf(id);
  if (!u.infinite && level >= 1) return false; // already owned
  for (final req in u.requires) {
    if (!meta.isUnlocked(req)) return false; // prerequisite missing
  }
  final cost = unlockCostForLevel(u, level);
  if (meta.soulPoints < cost) return false;
  meta.soulPoints -= cost;
  meta.ensureUnlockSlots(id + 1);
  meta.unlockLevels[id] += 1;
  return true;
}

/// Read-only view of meta progression for decoupled consumers (the P3 paywall
/// depends only on this, not on MetaState's storage). See docs/m3-plan.md.
abstract class MetaReader {
  int get soulPoints;
  bool isUnlocked(int id);
  int unlockLevel(int id);
  Iterable<UnlockDef> get allUnlocks;
  Iterable<UnlockDef> unlocksOfTier(String tier);
}

/// Concrete [MetaReader] over a [MetaState] + the balance's unlock defs.
class MetaView implements MetaReader {
  final MetaState _state;
  final List<UnlockDef> _unlocks;
  const MetaView(this._state, this._unlocks);
  @override
  int get soulPoints => _state.soulPoints;
  @override
  bool isUnlocked(int id) => _state.isUnlocked(id);
  @override
  int unlockLevel(int id) => _state.levelOf(id);
  @override
  Iterable<UnlockDef> get allUnlocks => _unlocks;
  @override
  Iterable<UnlockDef> unlocksOfTier(String tier) =>
      _unlocks.where((u) => u.tier == tier);
}
