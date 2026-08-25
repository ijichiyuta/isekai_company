import 'package:isekai_core/isekai_core.dart';

/// 堅実型ボット (requirements §18.1): steady prices, steady investment.
///
/// Deliberately STATELESS: every decision derives from the visible GameState,
/// so a save/load mid-life resumes bit-identically (determinism tests rely on
/// this). The development sweep index is a function of the current week.
///
/// This is a smoke-test driver for M0, not a calibrated player. Full bot
/// tuning against the balance gates (AC-07/08) is M2 work once the richer
/// economic model (demand curves, seasons, quality, employee levels) exists.
class SteadyBot {
  final Balance balance;
  late final List<(int, int, int)> _combos; // (matLo, matHi, method)

  SteadyBot(this.balance) {
    _combos = <(int, int, int)>[];
    for (var lo = 0; lo < balance.materials.length; lo++) {
      for (var hi = lo; hi < balance.materials.length; hi++) {
        for (var m = 0; m < balance.methods.length; m++) {
          _combos.add((lo, hi, m));
        }
      }
    }
  }

  bool _undiscoveredRemain(GameState s) {
    for (final r in balance.recipes) {
      if (!s.discovered[r.id] && r.band <= s.allowedBandMax) return true;
    }
    return false;
  }

  /// Mirrors the engine's demand formula (pre-jitter) so the bot doesn't
  /// overproduce past what a single product can sell in a week.
  int _demandPerProduct(GameState s) {
    final eco = balance.economy;
    final d = (eco.baseDemandX100 + s.fame * eco.demandPerFameX100) ~/ 100;
    return d < 1 ? 1 : d;
  }

  List<Command> decide(GameState s) {
    final cmds = <Command>[];
    final eco = balance.economy;

    // 1) Development: one experiment per week while discoverable recipes
    //    remain and we can cover the ≤6G material cost with a small buffer.
    //    Blind sweep in fixed order (no cheating with recipe knowledge); the
    //    hint system will speed real players up. Kept cheap so the bot never
    //    starves itself out of reaching a high-value recipe (e.g. pudding).
    if (s.week < _combos.length &&
        _undiscoveredRemain(s) &&
        s.funds > 20) {
      final (lo, hi, method) = _combos[s.week];
      if (lo == hi) {
        cmds.add(OrderMaterial(lo, 2));
      } else {
        cmds.add(OrderMaterial(lo, 1));
        cmds.add(OrderMaterial(hi, 1));
      }
      cmds.add(Develop(lo, hi, method));
    }

    // Discovered recipes, best margin first (stable tiebreak by id).
    final known = <RecipeDef>[];
    for (final r in balance.recipes) {
      if (s.discovered[r.id]) known.add(r);
    }
    known.sort((a, b) {
      final ma = a.basePrice - balance.recipeUnitCost(a);
      final mb = b.basePrice - balance.recipeUnitCost(b);
      return mb != ma ? mb - ma : a.id - b.id;
    });

    final capacity =
        eco.baseCapacityPerWeek + s.employees * eco.artisanOutputPerWeek;
    final demand = _demandPerProduct(s);

    // 2) Hire only once there is an income source (a known product) and we are
    //    capacity-constrained. Gating on known.isNotEmpty prevents the bot from
    //    spending its discovery capital on wages before it can produce.
    final sellableDemand = demand * known.length;
    if (known.isNotEmpty &&
        s.employees < eco.maxEmployees &&
        capacity < sellableDemand &&
        s.funds > eco.hireCost + eco.wageLv1 * 10) {
      cmds.add(Hire());
    }

    // 3) Produce: allocate whole units of capacity across products, each up to
    //    its per-week demand, best margin first. No fractional plans → the
    //    plan==0 starvation bug (capacity split N ways) cannot recur.
    var capLeft = capacity;
    for (final r in known) {
      if (capLeft <= 0) break;
      var want = demand < capLeft ? demand : capLeft;
      // Don't pile up more than ~2 weeks of unsold stock.
      final headroom = demand * 2 - s.productStock[r.id];
      if (want > headroom) want = headroom;
      if (want <= 0) continue;
      if (r.matA == r.matB) {
        cmds.add(OrderMaterial(r.matA, want * 2));
      } else {
        cmds.add(OrderMaterial(r.matA, want));
        cmds.add(OrderMaterial(r.matB, want));
      }
      cmds.add(Produce(r.id, want));
      capLeft -= want;
    }
    return cmds;
  }
}
