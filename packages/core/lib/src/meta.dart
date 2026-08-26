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
  /// infinite nodes (§8.4 #21/#22, `1000×1.6^n`). Indexed by unlock id — a List
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
}
