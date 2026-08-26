/// The deterministic tick engine: (state + commands + rng) → next state.
/// One tick = one in-game week (requirements §2.1). UI and bots submit the
/// same Command API — there is no other way to mutate state.
library;

import 'balance.dart';
import 'commands.dart';
import 'money.dart';
import 'state.dart';

class Engine {
  final Balance balance;
  Engine(this.balance);

  void tick(GameState s, List<Command> commands) {
    if (!s.alive) return;
    final eco = balance.economy;

    // Capacity snapshot at week start (hires take effect next week).
    final capacity =
        eco.baseCapacityPerWeek + s.employees * eco.artisanOutputPerWeek;
    var producedThisWeek = 0;
    var weeklyRevenue = 0;

    // --- 1. apply commands (in submission order) ---
    for (final c in commands) {
      switch (c) {
        case OrderMaterial(:final materialId, :final qty):
          if (materialId < 0 ||
              materialId >= balance.materials.length ||
              qty <= 0) {
            break;
          }
          final cost = balance.materials[materialId].cost * qty;
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
          if (r != null &&
              !s.discovered[r.id] &&
              r.band <= s.allowedBandMax) {
            s.discovered[r.id] = true;
            s.discoveries++;
            s.rewardEvents++;
            if (r.invention) {
              s.inventions++;
              s.funds += applyX100(r.basePrice, eco.inventionCashMultX100);
              s.fame =
                  clampCap(s.fame + applyX100(r.basePrice, eco.inventionFameMultX100));
            }
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

        case Grant(:final amount):
          // External inflows (offline rewards, IAP perks) — §2.2 rule 4.
          s.funds += amount;
      }
    }

    // --- 2. sales ---
    // Shared weekly demand POOL (requirements §6: the market is finite). Total
    // sales across all products are capped by the pool, so adding product lines
    // no longer multiplies demand (the old per-product model was pseudo-
    // infinite). Products draw from the pool in id order; price/season/trend
    // weighting of the allocation is M2. One jitter draw keeps the RNG draw
    // count per tick constant (determinism, §2.2). fame is clamped (below) so
    // pool*jitter and sold*basePrice cannot overflow int64 (§10.5).
    var pool = (eco.baseDemandX100 + s.fame * eco.demandPerFameX100) ~/ 100;
    final jitter = 95 + s.rng.economy.nextInt(11);
    pool = pool * jitter ~/ 100;
    for (var i = 0; i < balance.recipes.length; i++) {
      if (pool <= 0) break;
      final stock = s.productStock[i];
      if (stock == 0) continue;
      final sold = stock < pool ? stock : pool;
      s.productStock[i] -= sold;
      weeklyRevenue += sold * balance.recipes[i].basePrice;
      pool -= sold;
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

    // --- 5. rank up ---
    if (s.alive && s.rank + 1 < balance.ranks.length) {
      final next = balance.ranks[s.rank + 1];
      if (next.enabled &&
          s.funds >= next.minAssets &&
          s.fame >= next.minFame &&
          s.discoveries >= next.minRecipes &&
          s.employees >= next.minEmployees) {
        s.rank++;
        s.rankUps++;
        s.rewardEvents++;
        s.fame = clampCap(s.fame + eco.rankUpFameBonus);
      }
    }

    // --- 6. advance time ---
    s.week++;
    if (s.alive && s.week >= eco.lifespanWeeks) {
      s.alive = false;
      s.endReason = 'lifespan';
    }
  }
}
