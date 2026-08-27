/// Pure UI-progress math (no Flutter) so it can be unit-tested directly.
library;

/// Fraction 0.0–1.0 toward the next rank. Both gates (assets AND fame) must be
/// met, so the bar shows the *lesser* of the two ratios — it only fills when
/// the weaker requirement is satisfied. A zero threshold counts as already met,
/// and over/under values clamp into range (negative funds → 0.0).
double rankUpProgress({
  required int funds,
  required int fame,
  required int minAssets,
  required int minFame,
}) {
  final assets = minAssets == 0 ? 1.0 : (funds / minAssets).clamp(0.0, 1.0);
  final reputation = minFame == 0 ? 1.0 : (fame / minFame).clamp(0.0, 1.0);
  return assets < reputation ? assets : reputation;
}
