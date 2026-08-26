/// Analytics seam (要件§24 M4「分析」). The game emits funnel events through this
/// interface; the concrete client (Firebase/Amplitude/…) is wired in M4 with the
/// user's SDK keys. [NoopAnalytics] is the default so the game runs — and every
/// test runs — without any SDK or network. Swap via the provider.
///
/// Privacy: only aggregate gameplay-funnel events (no PII). ATT/SKAdNetwork/
/// privacy-manifest work lands with the real SDK (要件§13.x / §23.3).
abstract class AnalyticsClient {
  void event(String name, [Map<String, Object?> params]);
}

/// Does nothing — the safe default (no SDK, no network, deterministic tests).
class NoopAnalytics implements AnalyticsClient {
  const NoopAnalytics();
  @override
  void event(String name, [Map<String, Object?> params = const {}]) {}
}

/// The funnel event names, centralized so the analytics dashboard and the code
/// can't drift (§26 成功指標: 2周目突入率・課金率など).
class AnalyticsEvents {
  static const tutorialDone = 'tutorial_done';
  static const lifeEnd = 'life_end';
  static const rebirth = 'rebirth';
  static const unlockBought = 'unlock_bought';
  static const purchaseFull = 'purchase_full';
  static const restore = 'restore';
}
