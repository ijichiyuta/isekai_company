/// The deterministic tick engine: (state + commands + rng) → next state.
/// One tick = one in-game week (requirements §2.1). UI and bots submit the
/// same Command API — there is no other way to mutate state.
library;

import 'balance.dart';
import 'commands.dart';
import 'events.dart';
import 'money.dart';
import 'state.dart';

/// An invention that fired this tick, with its exact bonuses so the UI can show
/// the real numbers (§12.5) rather than guessing from a funds delta.
class InventionResult {
  final int recipeId;
  final int cashBonus;
  final int fameBonus;
  const InventionResult(this.recipeId, this.cashBonus, this.fameBonus);
}

/// What happened during a tick, for the UI/演出 layer. Bots and the headless
/// runner ignore it. Purely derived — the source of truth is [GameState].
class TickResult {
  final List<InventionResult> inventions;
  final int weeklyRevenue;
  final int weeklySold;
  final bool rankedUp;
  final int firedEventId; // event that fired this tick, or -1
  final bool trendOnset; // a trend was just announced this tick (v0.9 §7)
  const TickResult({
    required this.inventions,
    required this.weeklyRevenue,
    required this.weeklySold,
    required this.rankedUp,
    this.firedEventId = -1,
    this.trendOnset = false,
  });

  static const empty = TickResult(
      inventions: [], weeklyRevenue: 0, weeklySold: 0, rankedUp: false);
}

class Engine {
  final Balance balance;
  Engine(this.balance);

  TickResult tick(GameState s, List<Command> commands) {
    if (!s.alive) return TickResult.empty;
    final eco = balance.economy;
    final inventions = <InventionResult>[];

    // Capacity snapshot at week start (hires take effect next week). Equipment
    // level scales it (M3 §10.2): +equipStepX100% of base per level.
    final baseCapacity =
        eco.baseCapacityPerWeek + s.employees * eco.artisanOutputPerWeek;
    var capacity = clampCap(
        baseCapacity * (100 + s.equipmentLevel * eco.equipStepX100) ~/ 100);
    // 大量生産 / 商才の残響 (§8.4 #13/#22 production_bonus) scale capacity too.
    if (s.productionBonusX100 != 0) {
      capacity = clampCap(capacity * (100 + s.productionBonusX100) ~/ 100);
    }
    var producedThisWeek = 0;
    var weeklyRevenue = 0;
    var weeklySold = 0;

    // --- 1. apply commands (in submission order) ---
    for (final c in commands) {
      switch (c) {
        case OrderMaterial(:final materialId, :final qty):
          if (materialId < 0 ||
              materialId >= balance.materials.length ||
              qty <= 0) {
            break;
          }
          var cost = balance.materials[materialId].cost * qty;
          // 値切り交渉 (§8.4 #8 order_discount) cuts material cost.
          if (s.orderDiscountX100 != 0) {
            cost = cost * (100 - s.orderDiscountX100) ~/ 100;
          }
          if (s.funds >= cost) {
            s.funds -= cost;
            s.materialStock[materialId] += qty;
          }

        case Develop(:final matA, :final matB, :final method):
          if (matA < 0 ||
              matB < 0 ||
              matA >= balance.materials.length ||
              matB >= balance.materials.length) {
            break;
          }
          final lo = matA <= matB ? matA : matB;
          final hi = matA <= matB ? matB : matA;
          // Experimentation consumes one of each material (two if identical).
          if (lo == hi) {
            if (s.materialStock[lo] < 2) break;
            s.materialStock[lo] -= 2;
          } else {
            if (s.materialStock[lo] < 1 || s.materialStock[hi] < 1) break;
            s.materialStock[lo] -= 1;
            s.materialStock[hi] -= 1;
          }
          final r = balance.findRecipe(lo, hi, method);
          if (r != null) {
            final inv = _discover(s, r.id, eco);
            if (inv != null) inventions.add(inv);
          }

        case Discover(:final recipeId):
          if (recipeId >= 0 && recipeId < balance.recipes.length) {
            final inv = _discover(s, recipeId, eco);
            if (inv != null) inventions.add(inv);
          }

        case Produce(:final recipeId, :final qty):
          if (recipeId < 0 || recipeId >= balance.recipes.length || qty <= 0) {
            break;
          }
          if (!s.discovered[recipeId]) break;
          final r = balance.recipes[recipeId];
          var can = qty;
          final capLeft = capacity - producedThisWeek;
          if (can > capLeft) can = capLeft;
          if (r.matA == r.matB) {
            final byMat = s.materialStock[r.matA] ~/ 2;
            if (can > byMat) can = byMat;
          } else {
            if (can > s.materialStock[r.matA]) can = s.materialStock[r.matA];
            if (can > s.materialStock[r.matB]) can = s.materialStock[r.matB];
          }
          if (can <= 0) break;
          if (r.matA == r.matB) {
            s.materialStock[r.matA] -= 2 * can;
          } else {
            s.materialStock[r.matA] -= can;
            s.materialStock[r.matB] -= can;
          }
          s.productStock[recipeId] += can;
          producedThisWeek += can;

        case Hire():
          if (s.employees < eco.maxEmployees && s.funds >= eco.hireCost) {
            s.funds -= eco.hireCost;
            s.employees++;
          }

        case UpgradeEquipment():
          if (s.equipmentLevel < eco.equipMaxLevel) {
            final cost = _equipUpgradeCost(s, eco);
            if (s.funds >= cost) {
              s.funds -= cost;
              s.equipmentLevel++;
            }
          }

        case ImproveQuality():
          if (s.qualityStar < eco.qualityMultX100.length - 1) {
            final cost = _qualityUpgradeCost(s, eco);
            if (s.funds >= cost) {
              s.funds -= cost;
              s.qualityStar++;
            }
          }

        case Grant(:final amount):
          // External inflows (offline rewards, IAP perks) — §2.2 rule 4.
          s.funds += amount;

        case ChooseEvent(:final eventId, :final choiceIndex):
          // Resolve the pending event (§3.7): apply the chosen effects, clear.
          if (s.pendingEventId == eventId &&
              eventId >= 0 &&
              eventId < balance.events.length) {
            final ev = balance.events[eventId];
            if (choiceIndex >= 0 && choiceIndex < ev.choices.length) {
              for (final ef in ev.choices[choiceIndex].effects) {
                _applyEffect(s, ef, eco);
              }
              s.pendingEventId = -1;
            }
          }
      }
    }

    // --- 2. market (v0.9 §6/§7): season is week-derived (deterministic);
    // trends onset via RNG, announce for forecastWeeks, then run for
    // activeWeeks. ONLY when a market config exists — otherwise no draws and
    // uniform weights keep the tick byte-identical to the pre-v0.9 build (§2.2).
    final market = balance.market;
    final season = (s.week % 48) ~/ 12; // 48wk/yr, 12/season (matches app cal)
    var trendOnset = false;

    /// Ambient demand weight (x100): SEASON only. Trends are no longer folded in
    /// here — doing so let a trend-blind player auto-capture the spike (M-Fun-2).
    /// A live trend now pays out as a SEPARATE bonus pool (§7, below) that only
    /// the trending category's stock can absorb, so reacting to the forecast is
    /// a real decision. 100 everywhere with no market (→ uniform water-fill,
    /// byte-identical to pre-v0.9).
    int weightOf(int recipeId) {
      if (market == null) return 100;
      final cat = market.categoryIndex(balance.recipes[recipeId].category);
      final w = market.seasonMultOf(cat, season);
      return w < 1 ? 1 : w;
    }
    final trendLive =
        market != null && s.trendForecastWeeks == 0 && s.trendActiveWeeks > 0;

    // --- 2b. sales ---
    // Shared weekly demand POOL (requirements §6: the market is finite). A
    // WEIGHTED water-fill: each product's share is proportional to its demand
    // weight (season/trend), and shares freed by sell-outs redistribute. Equal
    // weights (no market) reduce this exactly to the fair uniform fill (M2
    // audit D-2). One jitter draw keeps the RNG structure stable (§2.2). The
    // running revenue sum is clampCap'd each step (§10.5).
    var pool = (eco.baseDemandX100 + s.fame * eco.demandPerFameX100) ~/ 100;
    final jitter = 95 + s.rng.economy.nextInt(11);
    pool = pool * jitter ~/ 100;
    // 棚割りの極意 (§8.4 #11 sales_bonus) widens the demand pool.
    if (s.salesBonusX100 != 0) pool = pool * (100 + s.salesBonusX100) ~/ 100;
    final basePool = pool; // snapshot: the trend bonus (2c) scales off this
    var active = <int>[];
    for (var i = 0; i < balance.recipes.length; i++) {
      if (s.productStock[i] > 0) active.add(i);
    }
    while (pool > 0 && active.isNotEmpty) {
      final roundPool = pool;
      var totalW = 0;
      for (final i in active) {
        totalW += weightOf(i);
      }
      var maxShare = 0;
      for (final i in active) {
        final sh = totalW == 0 ? 0 : roundPool * weightOf(i) ~/ totalW;
        if (sh > maxShare) maxShare = sh;
      }
      if (maxShare == 0) {
        // Fewer units of demand than active products: give one unit each in id
        // order until the pool is gone (bounded, deterministic).
        for (final i in active) {
          if (pool <= 0) break;
          s.productStock[i] -= 1;
          weeklyRevenue = clampCap(weeklyRevenue + _unitPrice(balance.recipes[i], s));
          weeklySold += 1;
          pool -= 1;
        }
        break;
      }
      final next = <int>[];
      for (final i in active) {
        final share = roundPool * weightOf(i) ~/ totalW;
        final stock = s.productStock[i];
        final sold = stock < share ? stock : share;
        s.productStock[i] -= sold;
        weeklyRevenue =
            clampCap(weeklyRevenue + sold * _unitPrice(balance.recipes[i], s));
        weeklySold += sold;
        pool -= sold;
        if (s.productStock[i] > 0) next.add(i);
      }
      active = next;
    }

    // --- 2c. trend bonus (M-Fun-2 §7): EXTRA demand only the trending category
    // can absorb. Stocking the forecast category ahead of the spike is now a
    // real, rewarded decision (a trend-blind player captures only whatever
    // trending stock they happen to hold). Uniform fill among trending stock,
    // scaled off the base pool by (mult-1). Consumes NO RNG and never runs
    // without a market → the no-market tick stays byte-identical (§2.2).
    if (trendLive) {
      var bonus = basePool * (s.trendMultX100 - 100) ~/ 100;
      var tActive = <int>[
        for (var i = 0; i < balance.recipes.length; i++)
          if (s.productStock[i] > 0 &&
              market!.categoryIndex(balance.recipes[i].category) ==
                  s.trendCategory)
            i,
      ];
      while (bonus > 0 && tActive.isNotEmpty) {
        final share = bonus ~/ tActive.length;
        if (share == 0) {
          for (final i in tActive) {
            if (bonus <= 0) break;
            s.productStock[i] -= 1;
            weeklyRevenue =
                clampCap(weeklyRevenue + _unitPrice(balance.recipes[i], s));
            weeklySold += 1;
            bonus -= 1;
          }
          break;
        }
        final next = <int>[];
        for (final i in tActive) {
          final stock = s.productStock[i];
          final sold = stock < share ? stock : share;
          s.productStock[i] -= sold;
          weeklyRevenue = clampCap(
              weeklyRevenue + sold * _unitPrice(balance.recipes[i], s));
          weeklySold += sold;
          bonus -= sold;
          if (s.productStock[i] > 0) next.add(i);
        }
        tActive = next;
      }
    }

    // Advance the trend AFTER this week's sales (so a live trend applies for its
    // full run): count down forecast→active→end, or roll a new onset. Only with
    // a market (no draws otherwise → byte-identical, §2.2).
    if (market != null) {
      if (s.trendForecastWeeks > 0) {
        s.trendForecastWeeks--; // announced, counting down to activation
      } else if (s.trendActiveWeeks > 0) {
        s.trendActiveWeeks--;
        if (s.trendActiveWeeks == 0) {
          s.trendCategory = -1;
          s.trendMultX100 = 0;
        }
      } else if (s.rng.economy.nextInt(market.trendAvgIntervalWeeks) == 0) {
        // Onset: pick category / duration / multiplier, forecast first.
        s.trendCategory = s.rng.economy.nextInt(market.categories.length);
        final span = market.trendMaxActiveWeeks - market.trendMinActiveWeeks + 1;
        s.trendActiveWeeks =
            market.trendMinActiveWeeks + s.rng.economy.nextInt(span);
        final mspan = market.trendMultMaxX100 - market.trendMultMinX100 + 1;
        s.trendMultX100 =
            market.trendMultMinX100 + s.rng.economy.nextInt(mspan);
        // 先読み発注 (§8.4 #10): a longer forecast window = more lead time to
        // stock the category (trendLeadX100 = 100 by default → unchanged).
        s.trendForecastWeeks =
            market.trendForecastWeeks * s.trendLeadX100 ~/ 100;
        trendOnset = true;
      }
    }
    s.funds += weeklyRevenue;
    s.totalRevenue = clampCap(s.totalRevenue + weeklyRevenue);
    s.fame = clampCap(s.fame + weeklyRevenue ~/ eco.famePerSalesG);

    // --- 3. weekly costs (rank fixed cost, wages, tax on revenue) ---
    final rankDef = balance.ranks[s.rank];
    s.funds -= rankDef.weeklyFixedCost;
    s.funds -= s.employees * eco.wageLv1;
    s.funds -= applyBp(weeklyRevenue, rankDef.taxBp);

    // Clamp funds to ±cap: keeps the negative side meaningful for bankruptcy
    // while preventing positive runaway overflow (requirements §10.5).
    s.funds = clampCap(s.funds);

    // --- 4. bankruptcy (requirements §8.1: funds<0 for grace weeks) ---
    if (s.funds < 0) {
      s.negativeStreak++;
    } else {
      s.negativeStreak = 0;
    }
    if (s.negativeStreak >= eco.bankruptcyGraceWeeks) {
      s.alive = false;
      s.endReason = 'bankrupt';
    }

    // --- 4b. events (only when this world has events; keeps headless hash
    // unchanged, audit A-D1/A-D2). Exactly two draws per tick regardless of
    // pool size / pending state (audit A-D3). Evaluated BEFORE rank-up so a
    // royal contract accepted this tick unlocks 御用達 immediately (A-D4).
    var firedEventId = -1;
    if (s.alive && balance.events.isNotEmpty) {
      final roll = s.rng.events.nextInt(1000); // draw 1 (always)
      final pick = s.rng.events.nextInt(1 << 30); // draw 2 (always)
      if (s.pendingEventId < 0) {
        s.eventDry++;
        final forcedId = _forcedEvent(s);
        if (forcedId >= 0) {
          // Forced (royal): tracked by royalCleared, NOT the shuffle-bag.
          firedEventId = forcedId;
          s.pendingEventId = forcedId;
          s.rewardEvents++;
          s.eventDry = 0;
        } else {
          // Fire on the random roll, OR guarantee one via the pity timer so a
          // long reward-free run can't happen (§10.4 reward pacing / AC-05).
          final pity = eco.eventPityTicks > 0 && s.eventDry >= eco.eventPityTicks;
          if (roll < eco.eventFirePermille || pity) {
            firedEventId = _selectWeighted(s, pick, pity);
            if (firedEventId >= 0) {
              s.pendingEventId = firedEventId;
              s.firedThisLife.add(firedEventId);
              s.rewardEvents++;
              s.eventDry = 0;
            }
          }
        }
      }
    }

    // --- 5. rank up ---
    var rankedUp = false;
    if (s.alive && s.rank + 1 < balance.ranks.length) {
      final next = balance.ranks[s.rank + 1];
      // 御用達 (the first rank gated by a royal event) also needs the royal
      // contract cleared — but only in a world that has events (§3.7 / A-D4).
      final royalOk = balance.events.isEmpty ||
          s.rank + 1 != _royalGatedRank ||
          s.royalCleared;
      if (next.enabled &&
          royalOk &&
          s.funds >= next.minAssets &&
          s.fame >= next.minFame &&
          s.discoveries >= next.minRecipes &&
          s.employees >= next.minEmployees) {
        s.rank++;
        s.rankUps++;
        s.rewardEvents++;
        s.fame = clampCap(s.fame + eco.rankUpFameBonus);
        rankedUp = true;
      }
    }

    // --- 6. advance time ---
    s.week++;
    if (s.alive && s.week >= eco.lifespanWeeks) {
      s.alive = false;
      s.endReason = 'lifespan';
    }

    return TickResult(
      inventions: inventions,
      weeklyRevenue: weeklyRevenue,
      weeklySold: weeklySold,
      rankedUp: rankedUp,
      firedEventId: firedEventId,
      trendOnset: trendOnset,
    );
  }

  /// The rank whose promotion is gated by the royal event (御用達 = rank 4).
  static const int _royalGatedRank = 4;

  /// A forced event (royal, fame-reached) eligible to fire, or -1. Pure state —
  /// consumes no RNG (audit A-D3/A-D4).
  int _forcedEvent(GameState s) {
    for (final e in balance.events) {
      if (e.forcedFameReached &&
          s.fame >= e.forcedValue &&
          !s.royalCleared && // fires until the contract is accepted
          e.minLife <= s.lifeNumber) {
        return e.id;
      }
    }
    return -1;
  }

  /// Weighted pick from the eligible pool using ONE pre-drawn [pick] value, so
  /// the RNG draw count never depends on pool size (audit A-D3). Non-forced
  /// events only. Shuffle-bag: when every eligible event has fired this life,
  /// the fired set resets so events keep flowing all life (no back-to-back
  /// repeats — §3.7 "same event not repeated"). Returns -1 only if nothing is
  /// eligible even after a reset (e.g. all gated by fame the player lacks).
  int _selectWeighted(GameState s, int pick, bool pityForced) {
    var total = _eligibleWeight(s);
    if (total <= 0) {
      // Normal firing respects §3.7 (no repeat within a life): reset the bag
      // ONLY when every non-forced event has genuinely fired. A pool emptied by
      // fame-gating is NOT a full bag → skip firing. BUT a pity-forced fire may
      // reset early to guarantee reward pacing (a rare re-show at the pity
      // cadence beats a long dead stretch — AC-05).
      if (!_bagFull(s) && !pityForced) return -1;
      s.firedThisLife.clear();
      total = _eligibleWeight(s);
      if (total <= 0) return -1;
    }
    var target = pick % total;
    for (final e in balance.events) {
      if (!_eligible(s, e)) continue;
      if (target < e.weight) return e.id;
      target -= e.weight;
    }
    return -1; // unreachable
  }

  int _eligibleWeight(GameState s) {
    var t = 0;
    for (final e in balance.events) {
      if (_eligible(s, e)) t += e.weight;
    }
    return t;
  }

  /// True when every non-forced event has already fired this life.
  bool _bagFull(GameState s) {
    for (final e in balance.events) {
      if (!e.forcedFameReached && !s.firedThisLife.contains(e.id)) return false;
    }
    return true;
  }

  bool _eligible(GameState s, EventDef e) =>
      !e.forcedFameReached &&
      e.minLife <= s.lifeNumber &&
      s.fame >= e.minFame &&
      s.fame <= e.maxFame &&
      !s.firedThisLife.contains(e.id);

  void _applyEffect(GameState s, EventEffect ef, EconomyDef eco) {
    switch (ef.type) {
      case 'funds':
        s.funds = clampCap(s.funds + ef.value);
      case 'fame':
        s.fame = clampCap(s.fame + ef.value);
      case 'grant_recipe':
        _discover(s, ef.refId, eco);
      case 'material':
        if (ef.refId >= 0 && ef.refId < s.materialStock.length) {
          final v = s.materialStock[ef.refId] + ef.value;
          s.materialStock[ef.refId] = v < 0 ? 0 : v;
        }
      case 'product':
        if (ef.refId >= 0 && ef.refId < s.productStock.length) {
          final v = s.productStock[ef.refId] + ef.value;
          s.productStock[ef.refId] = v < 0 ? 0 : v;
        }
      case 'royal_flag':
        s.royalCleared = true;
    }
  }

  /// Sale price of one unit of [r] given the shop's current quality star and
  /// the invention premium (M3 §10.2 / C-2). Integer, clamped so a high star ×
  /// premium can't overflow. quality star is clamped to the mult table length
  /// as a defensive measure (a valid life can't exceed it).
  int _unitPrice(RecipeDef r, GameState s) {
    final eco = balance.economy;
    final star = s.qualityStar < eco.qualityMultX100.length
        ? s.qualityStar
        : eco.qualityMultX100.length - 1;
    var p = clampCap(r.basePrice * eco.qualityMultX100[star] ~/ 100);
    if (r.invention && eco.inventionPricePremiumX100 != 100) {
      p = clampCap(p * eco.inventionPricePremiumX100 ~/ 100);
    }
    return p;
  }

  /// Geometric cost of the NEXT equipment level: base × mult^level (§10.2).
  int _equipUpgradeCost(GameState s, EconomyDef eco) {
    var c = eco.equipCostBase;
    for (var i = 0; i < s.equipmentLevel; i++) {
      c = clampCap(c * eco.equipCostMultX100 ~/ 100);
    }
    return c;
  }

  /// Geometric cost of the NEXT quality star: base × mult^star (§10.2).
  int _qualityUpgradeCost(GameState s, EconomyDef eco) {
    var c = eco.qualityCostBase;
    for (var i = 0; i < s.qualityStar; i++) {
      c = clampCap(c * eco.qualityCostMultX100 ~/ 100);
    }
    return c;
  }

  /// Discover [recipeId] if new and unlocked this life. Returns the invention
  /// bonuses if it was an invention, else null. Shared by Develop and Discover.
  InventionResult? _discover(GameState s, int recipeId, EconomyDef eco) {
    if (s.discovered[recipeId]) return null;
    final r = balance.recipes[recipeId];
    if (r.band > s.allowedBandMax) return null;
    s.discovered[recipeId] = true;
    s.discoveries++;
    s.rewardEvents++;
    if (!r.invention) return null;
    s.inventions++;
    final cash = applyX100(r.basePrice, eco.inventionCashMultX100);
    final fame = applyX100(r.basePrice, eco.inventionFameMultX100);
    s.funds += cash;
    s.fame = clampCap(s.fame + fame);
    return InventionResult(recipeId, cash, fame);
  }
}
