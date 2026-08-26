import 'package:isekai_core/isekai_core.dart';

/// 完全版 price label for the paywall (要件§13: 買い切り ¥1,200, 非消耗). MVP shows
/// this constant; M4 replaces it with the store-localized price from RevenueCat.
const String fullVersionPriceLabel = '¥1,200';

/// Legal document URLs (要件§23.3 / §14.4: 購入前に EULA・ポリシー・特商法 を提示).
/// Placeholders until the real hosted URLs land in M4 (needs-user).
const String eulaUrl = 'https://example.com/isekai-company/eula'; // TODO(M4)
const String privacyUrl = 'https://example.com/isekai-company/privacy'; // TODO(M4)
const String tokushohoUrl = 'https://example.com/isekai-company/tokushoho'; // TODO(M4)

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
        continue;
      }
      // Feature-gated (今後有効化) nodes aren't buyable yet — exclude them from
      // the "buyable / 完全版で解放" counts so the paywall never overstates the
      // value it actually unlocks now (景表法 — audit M4 P1).
      if (!isUnlockFunctional(u)) continue;
      if (u.tier == 'full') {
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
