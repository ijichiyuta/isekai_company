import 'package:isekai_core/isekai_core.dart';
import 'package:isekai_headless/isekai_headless.dart';
import 'package:test/test.dart';

/// A steady strategy that ALSO reacts to trends — identical to [SteadyBot]
/// except it front-loads the trending category (§7). Isolating the trend
/// reaction to a single variable lets M-Fun-2 be PROVEN: before the bonus-pool
/// change, a trend-blind player auto-captured the spike, so this edge was ~0%
/// (v0.9-B audit). Now the trend pays out as a separate pool only trending-
/// category stock can absorb, so stocking the forecast category earns real gold.
class _AwareSteady extends SteadyBot {
  _AwareSteady(super.balance);
  @override
  bool get trendAware => true;
}

void main() {
  test('M-Fun-2 §7: trend-aware steady out-earns trend-blind steady', () {
    final balance = loadBalanceFromDir('../../assets/balance',
        withMarket: true, withEvents: true);
    var awareTotal = 0, blindTotal = 0, blindWins = 0, tied = 0;
    const n = 40;
    for (var seed = 1; seed <= n; seed++) {
      final blind = runLife(balance, seed, botFactory: SteadyBot.new);
      final aware = runLife(balance, seed, botFactory: _AwareSteady.new);
      awareTotal += aware.totalRevenue;
      blindTotal += blind.totalRevenue;
      if (blind.totalRevenue > aware.totalRevenue) blindWins++;
      if (blind.totalRevenue == aware.totalRevenue) tied++;
    }
    // Aggregate edge is strictly positive (was 0% before the fix), and the
    // blind bot essentially never beats the aware one: they play identically
    // when no trend is live (→ ties), and the aware bot pulls ahead only when a
    // trend fires and it has stocked the trending category.
    expect(awareTotal, greaterThan(blindTotal),
        reason: 'aware=$awareTotal blind=$blindTotal ties=$tied');
    expect(blindWins, lessThanOrEqualTo(n ~/ 10),
        reason: 'blind beat aware on $blindWins/$n seeds');
  });
}
