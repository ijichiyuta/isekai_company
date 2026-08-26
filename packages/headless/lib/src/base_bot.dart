import 'package:isekai_core/isekai_core.dart';

import 'bot.dart';

/// Shared skeleton for the autoplay bots (requirements §18.1). Subclasses tune
/// behaviour via the override "knobs" rather than duplicating the decide loop.
///
/// STATELESS: every value derives from the passed [GameState] or from
/// immutable fields built in the constructor, so a save/load mid-life resumes
/// bit-identically (the determinism tests enforce this for every bot).
abstract class BaseBot implements Bot {
  final Balance balance;

  /// All (matLo, matHi, method) combos in a fixed order for the blind
  /// development sweep. Immutable after construction.
  late final List<(int, int, int)> combos;

  BaseBot(this.balance) {
    final c = <(int, int, int)>[];
    for (var lo = 0; lo < balance.materials.length; lo++) {
      for (var hi = lo; hi < balance.materials.length; hi++) {
        for (var m = 0; m < balance.methods.length; m++) {
          c.add((lo, hi, m));
        }
      }
    }
    combos = c;
  }

  // ---- knobs (override in subclasses) ----

  /// Run blind development experiments at all?
  bool get doDevelopment => true;

  /// Minimum funds required to spend on a development experiment.
  int get developMinFunds => 20;

  /// Hire when capacity-constrained and funds exceed hireCost + wage*this.
  int get hireWageBuffer => 10;

  /// Max employees this bot is willing to hire toward (capped by economy max).
  int get hireCeiling => balance.economy.maxEmployees;

  /// Weeks of unsold stock the bot tolerates before it stops producing a line.
  int get stockHeadroomWeeks => 2;

  /// Cash the bot keeps in reserve before spending on production materials.
  int get materialCashReserve => 0;

  // ---- shared helpers ----

  bool undiscoveredRemain(GameState s) {
    for (final r in balance.recipes) {
      if (!s.discovered[r.id] && r.band <= s.allowedBandMax) return true;
    }
    return false;
  }

  /// Estimated shared demand pool this week (mirrors the engine, pre-jitter).
  int poolEstimate(GameState s) {
    final eco = balance.economy;
    final d = (eco.baseDemandX100 + s.fame * eco.demandPerFameX100) ~/ 100;
    return d < 1 ? 1 : d;
  }

  List<RecipeDef> knownByMargin(GameState s) {
    final known = <RecipeDef>[];
    for (final r in balance.recipes) {
      if (s.discovered[r.id]) known.add(r);
    }
    known.sort((a, b) {
      final ma = a.basePrice - balance.recipeUnitCost(a);
      final mb = b.basePrice - balance.recipeUnitCost(b);
      return mb != ma ? mb - ma : a.id - b.id; // stable
    });
    return known;
  }

  int capacity(GameState s) =>
      balance.economy.baseCapacityPerWeek +
      s.employees * balance.economy.artisanOutputPerWeek;

  // ---- template decide() ----

  @override
  List<Command> decide(GameState s) {
    final cmds = <Command>[];
    final eco = balance.economy;

    // 1) Development sweep.
    if (doDevelopment &&
        s.week < combos.length &&
        undiscoveredRemain(s) &&
        s.funds > developMinFunds) {
      final (lo, hi, method) = combos[s.week];
      if (lo == hi) {
        cmds.add(OrderMaterial(lo, 2));
      } else {
        cmds.add(OrderMaterial(lo, 1));
        cmds.add(OrderMaterial(hi, 1));
      }
      cmds.add(Develop(lo, hi, method));
    }

    final known = knownByMargin(s);
    final cap = capacity(s);
    final pool = poolEstimate(s);

    // 2) Hire once there is an income source and the shared pool outstrips our
    //    capacity (more capacity only helps up to the pool size).
    if (known.isNotEmpty &&
        s.employees < hireCeiling &&
        cap < pool &&
        s.funds > eco.hireCost + eco.wageLv1 * hireWageBuffer) {
      cmds.add(Hire());
    }

    // Bot-specific extra commands (e.g. offline grants) before production.
    extraCommands(s, cmds);

    // 3) Produce toward the shared pool (+ headroom), best margin first. Total
    //    production is bounded by capacity AND by the pool, so we never pile up
    //    unsellable stock across the whole catalogue.
    var target = pool + pool * stockHeadroomWeeks;
    if (target > cap) target = cap;
    final maxStockPerLine = pool * (stockHeadroomWeeks + 1);
    var capLeft = target;
    for (final r in known) {
      if (capLeft <= 0) break;
      var want = capLeft;
      final headroom = maxStockPerLine - s.productStock[r.id];
      if (want > headroom) want = headroom;
      if (want <= 0) continue;
      final matCost = r.matA == r.matB
          ? balance.materials[r.matA].cost * 2 * want
          : (balance.materials[r.matA].cost + balance.materials[r.matB].cost) *
              want;
      if (s.funds - matCost < materialCashReserve) continue;
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

  /// Hook for bot-specific commands (default: none).
  void extraCommands(GameState s, List<Command> cmds) {}
}
