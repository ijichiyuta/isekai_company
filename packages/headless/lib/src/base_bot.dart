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

  /// Reinvest surplus funds into equipment (capacity) and quality (price)?
  /// The M3 §10.2 growth drivers — off by default (idle stays a passive floor).
  bool get reinvest => false;

  /// Only buy an upgrade when funds exceed its cost by this factor, so a
  /// purchase never starves the same week's production (geometric costs then
  /// throttle spending naturally).
  int get reinvestFundsMult => 4;

  // ---- shared helpers ----

  /// Cost of the next equipment level / quality star — mirrors the engine's
  /// geometric curve so the affordability check matches what the engine charges.
  int equipUpgradeCost(GameState s) {
    final eco = balance.economy;
    var c = eco.equipCostBase;
    for (var i = 0; i < s.equipmentLevel; i++) {
      c = c * eco.equipCostMultX100 ~/ 100;
    }
    return c;
  }

  int qualityUpgradeCost(GameState s) {
    final eco = balance.economy;
    var c = eco.qualityCostBase;
    for (var i = 0; i < s.qualityStar; i++) {
      c = c * eco.qualityCostMultX100 ~/ 100;
    }
    return c;
  }

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

  /// Effective sale price for margin ranking: includes the invention premium
  /// (C-2) so invented goods actually get produced. Quality applies equally to
  /// all products, so it doesn't change ordering and is left out.
  int _effPrice(RecipeDef r) {
    final eco = balance.economy;
    if (r.invention && eco.inventionPricePremiumX100 != 100) {
      return r.basePrice * eco.inventionPricePremiumX100 ~/ 100;
    }
    return r.basePrice;
  }

  List<RecipeDef> knownByMargin(GameState s) {
    final known = <RecipeDef>[];
    for (final r in balance.recipes) {
      if (s.discovered[r.id]) known.add(r);
    }
    known.sort((a, b) {
      final ma = _effPrice(a) - balance.recipeUnitCost(a);
      final mb = _effPrice(b) - balance.recipeUnitCost(b);
      return mb != ma ? mb - ma : a.id - b.id; // stable
    });
    return known;
  }

  int capacity(GameState s) {
    final eco = balance.economy;
    final base = eco.baseCapacityPerWeek + s.employees * eco.artisanOutputPerWeek;
    return base * (100 + s.equipmentLevel * eco.equipStepX100) ~/ 100;
  }

  // ---- template decide() ----

  @override
  List<Command> decide(GameState s) {
    final cmds = <Command>[];
    final eco = balance.economy;

    // 0) Resolve any pending event first (§3.7). Pick the choice with the best
    //    immediate funds outcome — survival-oriented, and it still accepts the
    //    royal contract (its accept branch grants funds). Strategy-specific
    //    (fame-seeking) choices are M2 polish.
    if (s.pendingEventId >= 0 && s.pendingEventId < balance.events.length) {
      final ev = balance.events[s.pendingEventId];
      var best = 0;
      var bestFunds = -1 << 62;
      for (var i = 0; i < ev.choices.length; i++) {
        var f = 0;
        for (final ef in ev.choices[i].effects) {
          if (ef.type == 'funds') f += ef.value;
        }
        if (f > bestFunds) {
          bestFunds = f;
          best = i;
        }
      }
      cmds.add(ChooseEvent(s.pendingEventId, best));
    }

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

    // 2b) Reinvest surplus into the §10.2 growth drivers. Quality lifts price
    //     on everything; equipment lifts capacity only when the shared pool
    //     already outstrips it. Buy only with a comfortable funds cushion so
    //     production isn't starved this week.
    if (reinvest && known.isNotEmpty) {
      final qMax = eco.qualityMultX100.length - 1;
      if (s.qualityStar < qMax) {
        final cost = qualityUpgradeCost(s);
        if (s.funds > cost * reinvestFundsMult) cmds.add(ImproveQuality());
      }
      if (s.equipmentLevel < eco.equipMaxLevel && cap < pool) {
        final cost = equipUpgradeCost(s);
        if (s.funds > cost * reinvestFundsMult) cmds.add(UpgradeEquipment());
      }
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
