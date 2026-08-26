import 'base_bot.dart';
import 'package:isekai_core/isekai_core.dart';

/// 回収型 (requirements §18.1): active bursts + offline income. Models the
/// commuter (ペルソナ A/C): plays like steady, and periodically collects an
/// offline reward injected through the Grant command path — exercising the
/// offline-progression rules (§17.2) so AC-09 (the funds/fame curve must hold
/// ±50% WITH offline injection) is verifiable.
///
/// The offline amount is a pure function of the visible state (stateless), so
/// determinism holds:
///   grant = min( estWeeklyProfit × offlineWeeks × 20%,  nextRankAssets × 10% )
/// The cap guarantees offline income can never skip a rank (§17.2).
class CollectionBot extends BaseBot {
  CollectionBot(Balance balance) : super(balance);

  static const int offlinePeriodWeeks = 24; // one offline collection per ~½yr
  static const int offlineWeeksEquivalent = 8; // modeled length of a gap
  static const int offlineFactorPct = 20; // §17.2 factor

  @override
  String get name => 'collection';

  int _estWeeklyProfit(GameState s) {
    final known = knownByMargin(s);
    if (known.isEmpty) return 0;
    // Real throughput is bounded by CAPACITY, not the (much larger) demand
    // pool — using the pool would wildly overstate offline income.
    final pool = poolEstimate(s);
    final cap = capacity(s);
    final volume = pool < cap ? pool : cap;
    final n = known.length < 3 ? known.length : 3;
    var margin = 0;
    for (var i = 0; i < n; i++) {
      margin += known[i].basePrice - balance.recipeUnitCost(known[i]);
    }
    margin ~/= n;
    final gross = volume * margin;
    final rankDef = balance.ranks[s.rank];
    final costs =
        rankDef.weeklyFixedCost + s.employees * balance.economy.wageLv1;
    final net = gross - costs;
    return net < 0 ? 0 : net;
  }

  int _nextRankCap(GameState s) {
    if (s.rank + 1 < balance.ranks.length) {
      final next = balance.ranks[s.rank + 1];
      if (next.enabled) return next.minAssets ~/ 10;
    }
    return balance.economy.startFunds * 100; // maxed rank fallback
  }

  @override
  void extraCommands(GameState s, List<Command> cmds) {
    if (s.week > 0 && s.week % offlinePeriodWeeks == 0) {
      final byProfit =
          (_estWeeklyProfit(s) * offlineWeeksEquivalent * offlineFactorPct) ~/
              100;
      final cap = _nextRankCap(s);
      final grant = byProfit < cap ? byProfit : cap;
      if (grant > 0) cmds.add(Grant(grant, 'offline'));
    }
  }
}

