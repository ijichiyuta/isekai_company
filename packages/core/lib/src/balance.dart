/// Balance definitions loaded from assets/balance/*.json.
/// Core never reads files itself (no dart:io) — callers pass parsed maps.
library;

import 'hash.dart';

class BalanceException implements Exception {
  final String message;
  BalanceException(this.message);
  @override
  String toString() => 'BalanceException: $message';
}

class MaterialDef {
  final int id;
  final String name;
  final int cost;
  const MaterialDef({required this.id, required this.name, required this.cost});
}

class RecipeDef {
  final int id;
  final String name;
  final int matA; // normalized: matA <= matB
  final int matB;
  final int method; // index into Balance.methods
  final int basePrice;
  final bool invention;
  final int band; // 1=life1, 2=life2+, 3=full version
  const RecipeDef({
    required this.id,
    required this.name,
    required this.matA,
    required this.matB,
    required this.method,
    required this.basePrice,
    required this.invention,
    required this.band,
  });
}

class RankDef {
  final int id;
  final String name;
  final int minAssets;
  final int minFame;
  final int minRecipes;
  final int minEmployees;
  final int weeklyFixedCost;
  final int taxBp;
  final bool enabled;
  const RankDef({
    required this.id,
    required this.name,
    required this.minAssets,
    required this.minFame,
    required this.minRecipes,
    required this.minEmployees,
    required this.weeklyFixedCost,
    required this.taxBp,
    required this.enabled,
  });
}

class EconomyDef {
  final int startFunds;
  final int lifespanWeeks;
  final int bankruptcyGraceWeeks;
  final int inventionCashMultX100;
  final int inventionFameMultX100;
  final int famePerSalesG;
  final int wageLv1;
  final int hireCost;
  final int artisanOutputPerWeek;
  final int baseCapacityPerWeek;
  final int baseDemandX100;
  final int demandPerFameX100;
  final int rankUpFameBonus;
  final int maxEmployees;
  const EconomyDef({
    required this.startFunds,
    required this.lifespanWeeks,
    required this.bankruptcyGraceWeeks,
    required this.inventionCashMultX100,
    required this.inventionFameMultX100,
    required this.famePerSalesG,
    required this.wageLv1,
    required this.hireCost,
    required this.artisanOutputPerWeek,
    required this.baseCapacityPerWeek,
    required this.baseDemandX100,
    required this.demandPerFameX100,
    required this.rankUpFameBonus,
    required this.maxEmployees,
  });
}

int _reqInt(Map<String, dynamic> m, String key, String file) {
  final v = m[key];
  if (v is! int) throw BalanceException('$file: "$key" must be int, got $v');
  return v;
}

String _reqStr(Map<String, dynamic> m, String key, String file) {
  final v = m[key];
  if (v is! String) {
    throw BalanceException('$file: "$key" must be string, got $v');
  }
  return v;
}

bool _reqBool(Map<String, dynamic> m, String key, String file) {
  final v = m[key];
  if (v is! bool) throw BalanceException('$file: "$key" must be bool, got $v');
  return v;
}

class Balance {
  final EconomyDef economy;
  final List<MaterialDef> materials;
  final List<RecipeDef> recipes;
  final List<RankDef> ranks;
  final List<String> methods;

  /// Replay-compatibility boundary (requirements §2.2 rule 7).
  final String contentHash;

  Balance._({
    required this.economy,
    required this.materials,
    required this.recipes,
    required this.ranks,
    required this.methods,
    required this.contentHash,
  });

  factory Balance.fromJsonMaps({
    required Map<String, dynamic> economyJson,
    required Map<String, dynamic> materialsJson,
    required Map<String, dynamic> recipesJson,
    required Map<String, dynamic> ranksJson,
  }) {
    for (final (name, m) in [
      ('economy.json', economyJson),
      ('materials.json', materialsJson),
      ('recipes.json', recipesJson),
      ('ranks.json', ranksJson),
    ]) {
      if (m['schema_version'] != 1) {
        throw BalanceException('$name: unsupported schema_version');
      }
    }

    final economy = EconomyDef(
      startFunds: _reqInt(economyJson, 'start_funds', 'economy.json'),
      lifespanWeeks: _reqInt(economyJson, 'lifespan_weeks', 'economy.json'),
      bankruptcyGraceWeeks:
          _reqInt(economyJson, 'bankruptcy_grace_weeks', 'economy.json'),
      inventionCashMultX100:
          _reqInt(economyJson, 'invention_cash_mult_x100', 'economy.json'),
      inventionFameMultX100:
          _reqInt(economyJson, 'invention_fame_mult_x100', 'economy.json'),
      famePerSalesG: _reqInt(economyJson, 'fame_per_sales_g', 'economy.json'),
      wageLv1: _reqInt(economyJson, 'wage_lv1', 'economy.json'),
      hireCost: _reqInt(economyJson, 'hire_cost', 'economy.json'),
      artisanOutputPerWeek:
          _reqInt(economyJson, 'artisan_output_per_week', 'economy.json'),
      baseCapacityPerWeek:
          _reqInt(economyJson, 'base_capacity_per_week', 'economy.json'),
      baseDemandX100: _reqInt(economyJson, 'base_demand_x100', 'economy.json'),
      demandPerFameX100:
          _reqInt(economyJson, 'demand_per_fame_x100', 'economy.json'),
      rankUpFameBonus:
          _reqInt(economyJson, 'rank_up_fame_bonus', 'economy.json'),
      maxEmployees: _reqInt(economyJson, 'max_employees', 'economy.json'),
    );

    final materials = <MaterialDef>[];
    for (final raw in materialsJson['materials'] as List) {
      final m = raw as Map<String, dynamic>;
      final cost = _reqInt(m, 'cost', 'materials.json');
      if (cost < 0) throw BalanceException('materials.json: cost must be >= 0');
      materials.add(MaterialDef(
        id: _reqInt(m, 'id', 'materials.json'),
        name: _reqStr(m, 'name', 'materials.json'),
        cost: cost,
      ));
    }
    if (materials.isEmpty) {
      throw BalanceException('materials.json: must define at least one material');
    }
    for (var i = 0; i < materials.length; i++) {
      if (materials[i].id != i) {
        throw BalanceException('materials.json: ids must be sequential');
      }
    }

    final methods = (recipesJson['methods'] as List).cast<String>();
    final recipes = <RecipeDef>[];
    for (final raw in recipesJson['recipes'] as List) {
      final m = raw as Map<String, dynamic>;
      final a = _reqInt(m, 'mat_a', 'recipes.json');
      final b = _reqInt(m, 'mat_b', 'recipes.json');
      final methodName = m['method'] as String;
      final method = methods.indexOf(methodName);
      if (method < 0) {
        throw BalanceException('recipes.json: unknown method "$methodName"');
      }
      if (a >= materials.length || b >= materials.length || a < 0 || b < 0) {
        throw BalanceException('recipes.json: material ref out of range');
      }
      final band = _reqInt(m, 'band', 'recipes.json');
      if (band < 1 || band > 3) {
        throw BalanceException('recipes.json: band must be 1..3');
      }
      final basePrice = _reqInt(m, 'base_price', 'recipes.json');
      if (basePrice < 0) {
        throw BalanceException('recipes.json: base_price must be >= 0');
      }
      recipes.add(RecipeDef(
        id: _reqInt(m, 'id', 'recipes.json'),
        name: _reqStr(m, 'name', 'recipes.json'),
        matA: a <= b ? a : b,
        matB: a <= b ? b : a,
        method: method,
        basePrice: basePrice,
        invention: _reqBool(m, 'invention', 'recipes.json'),
        band: band,
      ));
    }
    if (recipes.isEmpty) {
      throw BalanceException('recipes.json: must define at least one recipe');
    }
    for (var i = 0; i < recipes.length; i++) {
      if (recipes[i].id != i) {
        throw BalanceException('recipes.json: ids must be sequential');
      }
    }
    // Duplicate (matA, matB, method) would make findRecipe order-dependent.
    for (var i = 0; i < recipes.length; i++) {
      for (var j = i + 1; j < recipes.length; j++) {
        if (recipes[i].matA == recipes[j].matA &&
            recipes[i].matB == recipes[j].matB &&
            recipes[i].method == recipes[j].method) {
          throw BalanceException(
              'recipes.json: duplicate combo (recipes ${i} and ${j})');
        }
      }
    }

    final ranks = <RankDef>[];
    for (final raw in ranksJson['ranks'] as List) {
      final m = raw as Map<String, dynamic>;
      ranks.add(RankDef(
        id: _reqInt(m, 'id', 'ranks.json'),
        name: _reqStr(m, 'name', 'ranks.json'),
        minAssets: _reqInt(m, 'min_assets', 'ranks.json'),
        minFame: _reqInt(m, 'min_fame', 'ranks.json'),
        minRecipes: _reqInt(m, 'min_recipes', 'ranks.json'),
        minEmployees: _reqInt(m, 'min_employees', 'ranks.json'),
        weeklyFixedCost: _reqInt(m, 'weekly_fixed_cost', 'ranks.json'),
        taxBp: _reqInt(m, 'tax_bp', 'ranks.json'),
        enabled: _reqBool(m, 'enabled', 'ranks.json'),
      ));
    }
    if (ranks.isEmpty) {
      throw BalanceException('ranks.json: must define at least one rank');
    }
    for (var i = 0; i < ranks.length; i++) {
      if (ranks[i].id != i) {
        throw BalanceException('ranks.json: ids must be sequential');
      }
      // The primary progression axes (assets, fame) must be nondecreasing so a
      // higher rank is never cheaper on them (§10.3). min_recipes/min_employees
      // are situational gates that legitimately drop at higher ranks (e.g. 御用達
      // needs 0 employees but a royal-event clear instead), so they're exempt.
      if (i > 0) {
        final prev = ranks[i - 1];
        final cur = ranks[i];
        if (cur.minAssets < prev.minAssets || cur.minFame < prev.minFame) {
          throw BalanceException(
              'ranks.json: min_assets/min_fame must be nondecreasing (rank $i)');
        }
      }
    }

    final contentHash = hashHex(fnv1a64(canonicalJson({
      'economy': economyJson,
      'materials': materialsJson,
      'recipes': recipesJson,
      'ranks': ranksJson,
    })));

    return Balance._(
      economy: economy,
      materials: materials,
      recipes: recipes,
      ranks: ranks,
      methods: methods,
      contentHash: contentHash,
    );
  }

  int recipeUnitCost(RecipeDef r) =>
      materials[r.matA].cost + materials[r.matB].cost;

  /// Exact-match lookup. [a]/[b] need not be normalized. Linear scan is fine
  /// at MVP scale (≤300 recipes) and keeps iteration order trivially stable.
  RecipeDef? findRecipe(int a, int b, int method) {
    final lo = a <= b ? a : b;
    final hi = a <= b ? b : a;
    for (final r in recipes) {
      if (r.matA == lo && r.matB == hi && r.method == method) return r;
    }
    return null;
  }
}
