import 'package:flutter/foundation.dart';

/// In-app-purchase seam. The completion product (完全版) is a single
/// non-consumable. [StubIapClient] stands in for MVP; a RevenueCatIapClient
/// lands in M4 (requirements §16 — RevenueCat deferred), swapped via the
/// provider without touching callers.
abstract class IapClient {
  /// True when a real store is wired. The release stub returns false so the UI
  /// shows 「準備中」 and disables the buy button (M3 release is NOT submitted
  /// for review — the store product doesn't exist yet).
  bool get available;

  /// Buy 完全版. Returns true on a completed purchase.
  Future<bool> purchaseFull();

  /// Restore a prior non-consumable purchase (App Store 3.1.1 requirement).
  Future<bool> restore();
}

/// Debug: 完全版 succeeds instantly so the flow is testable/dev-usable.
/// Release: unavailable — every method is gated on [kReleaseMode], which the
/// AOT compiler folds to a constant `false`, so the debug success path can never
/// ship as a free unlock. The M3 release build is NOT submitted for review
/// (no store product yet); see ADR-0003.
class StubIapClient implements IapClient {
  @override
  bool get available => !kReleaseMode;

  @override
  Future<bool> purchaseFull() async => !kReleaseMode;

  @override
  Future<bool> restore() async => false; // the stub has nothing to restore
}
