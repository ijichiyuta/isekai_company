import 'package:isekai_core/isekai_core.dart';

/// Non-consumable purchase state (完全版). The single paid product for MVP
/// unlocks every 'full'-tier soul-memory node (§8.4) plus the premium features.
/// Persisted SEPARATELY from the game save (balance-hash-independent) so an
/// economy/balance change can never wipe a purchase record (audit P3 High-2).
/// In M4 the authority moves to RevenueCat; this local copy becomes an offline
/// cache.
class Entitlements {
  bool isFull;
  Entitlements({this.isFull = false});

  /// May the player buy [u] right now? free/auto are always allowed (auto #3 is
  /// non-paid); 'full' needs the 完全版 purchase — the §8.4 tier boundary. NOTE
  /// #16 自動発注 is 'free', so it is NEVER gated (audit Critical-1).
  bool canPurchase(UnlockDef u) => u.tier != 'full' || isFull;

  Map<String, dynamic> toJson() => {'is_full': isFull};
  factory Entitlements.fromJson(Map<String, dynamic> m) =>
      Entitlements(isFull: (m['is_full'] as bool?) ?? false);
}

/// Dynamic unlock accounting for the paywall / tree UI. AC-16: never hardcode
/// "あと N個で全解放" — derive every count from balance.unlocks so adding a node
/// updates every screen automatically.
class UnlockSummary {
  final int total; // all purchasable/grantable nodes
  final int owned; // nodes owned (level >= 1)
  final int freeReachable; // free/auto nodes not yet owned (buyable w/o 完全版)
  final int fullLocked; // full nodes not yet owned (need 完全版)
  const UnlockSummary({
    required this.total,
    required this.owned,
    required this.freeReachable,
    required this.fullLocked,
  });

  /// How many more nodes 完全版 makes purchasable right now (paywall headline).
  int get unlockedByFull => fullLocked;

  static UnlockSummary compute(MetaReader meta) {
    var total = 0, owned = 0, freeReachable = 0, fullLocked = 0;
    for (final u in meta.allUnlocks) {
      total++;
      if (meta.isUnlocked(u.id)) {
        owned++;
      } else if (u.tier == 'full') {
        fullLocked++;
      } else {
        freeReachable++; // free or auto
      }
    }
    return UnlockSummary(
      total: total,
      owned: owned,
      freeReachable: freeReachable,
      fullLocked: fullLocked,
    );
  }
}
