/// Balance definitions loaded from assets/balance/*.json.
/// Core never reads files itself (no dart:io) — callers pass parsed maps.
library;

import 'events.dart';
import 'hash.dart';
import 'meta.dart';

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
  final String category; // market category (v0.9 season/trend); '' if absent
  const RecipeDef({
    required this.id,
    required this.name,
    required this.matA,
    required this.matB,
    required this.method,
    required this.basePrice,
    required this.invention,
    required this.band,
    this.category = '',
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
  final int eventFirePermille; // per-tick event fire chance (‰), 0 = never
  final int eventPityTicks; // guarantee an event if none in this many ticks, 0 = off
  // --- Reinvestment drivers (M3 P1, §10.2). All default to "no effect" so a
  // balance without these keys behaves exactly as pre-M3 (ADR-0002). ---
  final int equipCostBase; // cost of the 1st equipment level
  final int equipCostMultX100; // each level costs ×this/100 the previous
  final int equipStepX100; // each level adds this% of base capacity
  final int equipMaxLevel; // 0 = equipment upgrades disabled
  final int qualityCostBase; // cost of the 1st quality star
  final int qualityCostMultX100; // each star costs ×this/100 the previous
  final List<int> qualityMultX100; // price ×mult/100 by star; [0] must be 100
  final int inventionPricePremiumX100; // inventions sell ×this/100 (C-2), 100=off
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
    required this.eventFirePermille,
    required this.eventPityTicks,
    required this.equipCostBase,
    required this.equipCostMultX100,
    required this.equipStepX100,
    required this.equipMaxLevel,
    required this.qualityCostBase,
    required this.qualityCostMultX100,
    required this.qualityMultX100,
    required this.inventionPricePremiumX100,
  });
}

int _reqInt(Map<String, dynamic> m, String key, String file) {
  final v = m[key];
  if (v is! int) throw BalanceException('$file: "$key" must be int, got $v');
  return v;
}

/// Season/trend market (v0.9 §6/§7). Absent → null (byte-identical pre-v0.9).
/// Validates: categories cover every recipe category, each season array has 4
/// entries, multipliers positive, trend windows sane.
MarketDef? _parseMarket(Map<String, dynamic>? json, List<RecipeDef> recipes) {
  if (json == null) return null;
  const f = 'market.json';
  if (json['schema_version'] != 1) {
    throw BalanceException('$f: unsupported schema_version');
  }
  final cats = <String>[];
  for (final c in _reqList(json, 'categories', f)) {
    if (c is! String) throw BalanceException('$f: categories must be strings');
    cats.add(c);
  }
  if (cats.isEmpty) throw BalanceException('$f: categories empty');
  // Every recipe's (non-empty) category must be known.
  for (final r in recipes) {
    if (r.category.isNotEmpty && !cats.contains(r.category)) {
      throw BalanceException('$f: recipe "${r.name}" category "${r.category}" '
          'not in categories');
    }
  }
  final scmRaw = _reqMap(json['season_category_mult'], f);
  final seasonMult = <List<int>>[];
  for (final cat in cats) {
    final arr = scmRaw[cat];
    if (arr is! List || arr.length != 4) {
      throw BalanceException('$f: season_category_mult["$cat"] must have 4 ints');
    }
    final row = <int>[];
    for (final v in arr) {
      if (v is! int || v < 1 || v > 100000) {
        throw BalanceException('$f: season mult must be int in [1,100000]');
      }
      row.add(v);
    }
    seasonMult.add(row);
  }
  final t = _reqMap(json['trend'], f);
  final minA = _rangedInt(t, 'min_active_weeks', f, min: 1);
  final maxA = _rangedInt(t, 'max_active_weeks', f, min: 1);
  if (maxA < minA) throw BalanceException('$f: max_active < min_active');
  final minM = _rangedInt(t, 'mult_min_x100', f, min: 100);
  final maxM = _rangedInt(t, 'mult_max_x100', f, min: 100);
  if (maxM < minM) throw BalanceException('$f: mult_max < mult_min');
  return MarketDef(
    categories: cats,
    seasonMult: seasonMult,
    trendAvgIntervalWeeks: _rangedInt(t, 'avg_interval_weeks', f, min: 1),
    trendForecastWeeks: _rangedInt(t, 'forecast_weeks', f),
    trendMinActiveWeeks: minA,
    trendMaxActiveWeeks: maxA,
    trendMultMinX100: minM,
    trendMultMaxX100: maxM,
  );
}

/// 魂の記憶 tree (§8.4). Absent → empty (headless / pre-M3 keep their hash).
/// Ids must be sequential (so a node id indexes both `unlocks` and
/// meta.unlockLevels), tiers valid, requires in range and backward (a node's
/// prerequisites have smaller ids — prevents cycles), costs non-negative.
List<UnlockDef> _parseUnlocks(Map<String, dynamic>? json) {
  if (json == null) return const <UnlockDef>[];
  const f = 'unlocks.json';
  if (json['schema_version'] != 1) {
    throw BalanceException('$f: unsupported schema_version');
  }
  const validTiers = {'free', 'full', 'auto'};
  final out = <UnlockDef>[];
  for (final raw in _reqList(json, 'unlocks', f)) {
    final m = _reqMap(raw, f);
    final id = _reqInt(m, 'id', f);
    final tier = _reqStr(m, 'tier', f);
    if (!validTiers.contains(tier)) {
      throw BalanceException('$f: unknown tier "$tier" (id $id)');
    }
    final requires = <int>[];
    for (final r in _reqList(m, 'requires', f)) {
      if (r is! int || r < 0 || r >= id) {
        throw BalanceException(
            '$f: requires must reference an earlier node id (id $id, got $r)');
      }
      requires.add(r);
    }
    out.add(UnlockDef(
      id: id,
      key: _reqStr(m, 'key', f),
      name: _reqStr(m, 'name', f),
      desc: _reqStr(m, 'desc', f),
      cost: _rangedInt(m, 'cost', f),
      tier: tier,
      requires: requires,
      modType: _reqStr(m, 'mod_type', f),
      modValue: _reqInt(m, 'mod_value', f),
      infinite: _reqBool(m, 'infinite', f),
    ));
  }
  for (var i = 0; i < out.length; i++) {
    if (out[i].id != i) throw BalanceException('$f: ids must be sequential');
  }
  return out;
}

/// quality_mult_x100: price multiplier per quality star. [0] must be 100 (star
/// 0 = base price) and the sequence must be nondecreasing (a higher star is
/// never cheaper). Absent → [100] (quality disabled). M3 P1 / §10.2.
List<int> _parseQualityMult(Map<String, dynamic> m, String file) {
  if (!m.containsKey('quality_mult_x100')) return const <int>[100];
  final raw = _reqList(m, 'quality_mult_x100', file);
  final out = <int>[];
  for (final v in raw) {
    if (v is! int || v < 1 || v > 1000000) {
      throw BalanceException(
          '$file: quality_mult_x100 entries must be ints in [1, 1000000], '
          'got $v');
    }
    out.add(v);
  }
  if (out.isEmpty || out.first != 100) {
    throw BalanceException('$file: quality_mult_x100[0] must be 100');
  }
  for (var i = 1; i < out.length; i++) {
    if (out[i] < out[i - 1]) {
      throw BalanceException(
          '$file: quality_mult_x100 must be nondecreasing (index $i)');
    }
  }
  return out;
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

List _reqList(Map<String, dynamic> m, String key, String file) {
  final v = m[key];
  if (v is! List) throw BalanceException('$file: "$key" must be a list, got $v');
  return v;
}

Map<String, dynamic> _reqMap(Object? raw, String file) {
  if (raw is! Map<String, dynamic>) {
    throw BalanceException('$file: expected an object, got $raw');
  }
  return raw;
}

/// int within [min, max] inclusive (defaults keep values inside the 1e15 game
/// ceiling so no downstream arithmetic can overflow int64, §10.5).
int _rangedInt(Map<String, dynamic> m, String key, String file,
    {int min = 0, int max = 1000000000000000}) {
  final v = _reqInt(m, key, file);
  if (v < min || v > max) {
    throw BalanceException('$file: "$key" must be in [$min, $max], got $v');
  }
  return v;
}

/// Season/trend market config (v0.9, §6/§7). Seasons multiply per-category
/// demand (±30-50%); trends spike one category (×2-3) for a stretch with a
/// forecast lead. All multipliers are x100 (100 = neutral).
class MarketDef {
  final List<String> categories;
  // seasonMult[categoryIndex][season 0..3] — demand multiplier, x100.
  final List<List<int>> seasonMult;
  final int trendAvgIntervalWeeks; // mean weeks between trends
  final int trendForecastWeeks; // announced this many weeks before it starts
  final int trendMinActiveWeeks;
  final int trendMaxActiveWeeks;
  final int trendMultMinX100;
  final int trendMultMaxX100;
  const MarketDef({
    required this.categories,
    required this.seasonMult,
    required this.trendAvgIntervalWeeks,
    required this.trendForecastWeeks,
    required this.trendMinActiveWeeks,
    required this.trendMaxActiveWeeks,
    required this.trendMultMinX100,
    required this.trendMultMaxX100,
  });

  /// Category index for [category], or -1 (neutral) if unknown/empty.
  int categoryIndex(String category) => categories.indexOf(category);

  /// Season demand multiplier (x100) for [categoryIndex] in [season] (0..3).
  /// Neutral (100) for an out-of-range category.
  int seasonMultOf(int categoryIndex, int season) =>
      categoryIndex >= 0 && categoryIndex < seasonMult.length
          ? seasonMult[categoryIndex][season]
          : 100;
}

class Balance {
  final EconomyDef economy;
  final List<MaterialDef> materials;
  final List<RecipeDef> recipes;
  final List<RankDef> ranks;
  final List<String> methods;
  final List<EventDef> events;

  /// 魂の記憶 tree (§8.4). Empty unless unlocks.json is supplied (headless and
  /// pre-M3 tests pass none, keeping the content hash unchanged — like events).
  final List<UnlockDef> unlocks;

  /// Season/trend market config (v0.9, §6/§7). null unless market.json is
  /// supplied — absent = no season/trend (byte-identical to the pre-v0.9 build).
  final MarketDef? market;

  /// Replay-compatibility boundary (requirements §2.2 rule 7).
  final String contentHash;

  Balance._({
    required this.economy,
    required this.materials,
    required this.recipes,
    required this.ranks,
    required this.methods,
    required this.events,
    required this.unlocks,
    required this.market,
    required this.contentHash,
  });

  /// Normalizes ANY parse failure (missing keys, wrong types, bad casts) to a
  /// [BalanceException] so a corrupt/modded balance file can never crash the
  /// app with a raw TypeError — the loader boundary catches one type.
  ///
  /// [eventsJson] is optional: headless and tests pass no events, keeping the
  /// content hash and behaviour identical to the pre-events build (audit A-D1).
  factory Balance.fromJsonMaps({
    required Map<String, dynamic> economyJson,
    required Map<String, dynamic> materialsJson,
    required Map<String, dynamic> recipesJson,
    required Map<String, dynamic> ranksJson,
    Map<String, dynamic>? eventsJson,
    Map<String, dynamic>? unlocksJson,
    Map<String, dynamic>? marketJson,
  }) {
    try {
      return Balance._build(
        economyJson: economyJson,
        materialsJson: materialsJson,
        recipesJson: recipesJson,
        ranksJson: ranksJson,
        eventsJson: eventsJson,
        unlocksJson: unlocksJson,
        marketJson: marketJson,
      );
    } on BalanceException {
      rethrow;
    } on EventsException catch (e) {
      throw BalanceException(e.message);
    } catch (e) {
      throw BalanceException('malformed balance JSON: $e');
    }
  }

  static Balance _build({
    required Map<String, dynamic> economyJson,
    required Map<String, dynamic> materialsJson,
    required Map<String, dynamic> recipesJson,
    required Map<String, dynamic> ranksJson,
    Map<String, dynamic>? eventsJson,
    Map<String, dynamic>? unlocksJson,
    Map<String, dynamic>? marketJson,
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

    // All economy values are non-negative and bounded (§10.5); famePerSalesG is
    // a divisor so it must be >= 1, and multipliers/divisors get a sane ceiling
    // so applyBp/applyX100 can never overflow int64.
    const c = 'economy.json';
    final economy = EconomyDef(
      startFunds: _rangedInt(economyJson, 'start_funds', c),
      lifespanWeeks: _rangedInt(economyJson, 'lifespan_weeks', c, min: 1),
      bankruptcyGraceWeeks:
          _rangedInt(economyJson, 'bankruptcy_grace_weeks', c, min: 1),
      inventionCashMultX100:
          _rangedInt(economyJson, 'invention_cash_mult_x100', c, max: 1000000),
      inventionFameMultX100:
          _rangedInt(economyJson, 'invention_fame_mult_x100', c, max: 1000000),
      famePerSalesG: _rangedInt(economyJson, 'fame_per_sales_g', c, min: 1),
      wageLv1: _rangedInt(economyJson, 'wage_lv1', c),
      hireCost: _rangedInt(economyJson, 'hire_cost', c),
      artisanOutputPerWeek: _rangedInt(economyJson, 'artisan_output_per_week', c),
      baseCapacityPerWeek: _rangedInt(economyJson, 'base_capacity_per_week', c),
      baseDemandX100: _rangedInt(economyJson, 'base_demand_x100', c),
      demandPerFameX100:
          _rangedInt(economyJson, 'demand_per_fame_x100', c, max: 1000000),
      rankUpFameBonus: _rangedInt(economyJson, 'rank_up_fame_bonus', c),
      maxEmployees: _rangedInt(economyJson, 'max_employees', c, max: 1000000),
      // Optional: absent → 0 (no events). Set in economy.json for the app.
      eventFirePermille: economyJson.containsKey('event_fire_permille')
          ? _rangedInt(economyJson, 'event_fire_permille', c, max: 1000)
          : 0,
      eventPityTicks: economyJson.containsKey('event_pity_ticks')
          ? _rangedInt(economyJson, 'event_pity_ticks', c, max: 100000)
          : 0,
      equipCostBase: economyJson.containsKey('equip_cost_base')
          ? _rangedInt(economyJson, 'equip_cost_base', c)
          : 0,
      equipCostMultX100: economyJson.containsKey('equip_cost_mult_x100')
          ? _rangedInt(economyJson, 'equip_cost_mult_x100', c,
              min: 100, max: 1000000)
          : 100,
      equipStepX100: economyJson.containsKey('equip_step_x100')
          ? _rangedInt(economyJson, 'equip_step_x100', c, max: 1000000)
          : 0,
      equipMaxLevel: economyJson.containsKey('equip_max_level')
          ? _rangedInt(economyJson, 'equip_max_level', c, max: 1000)
          : 0,
      qualityCostBase: economyJson.containsKey('quality_cost_base')
          ? _rangedInt(economyJson, 'quality_cost_base', c)
          : 0,
      qualityCostMultX100: economyJson.containsKey('quality_cost_mult_x100')
          ? _rangedInt(economyJson, 'quality_cost_mult_x100', c,
              min: 100, max: 1000000)
          : 100,
      qualityMultX100: _parseQualityMult(economyJson, c),
      inventionPricePremiumX100:
          economyJson.containsKey('invention_price_premium_x100')
              ? _rangedInt(economyJson, 'invention_price_premium_x100', c,
                  min: 100, max: 1000000)
              : 100,
    );

    final materials = <MaterialDef>[];
    for (final raw in _reqList(materialsJson, 'materials', 'materials.json')) {
      final m = _reqMap(raw, 'materials.json');
      materials.add(MaterialDef(
        id: _reqInt(m, 'id', 'materials.json'),
        name: _reqStr(m, 'name', 'materials.json'),
        cost: _rangedInt(m, 'cost', 'materials.json'),
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

    // Materialize + validate every method eagerly: a lazy `.cast<String>()`
    // would let a non-string element slip through until it's dereferenced.
    final methods = <String>[];
    for (final raw in _reqList(recipesJson, 'methods', 'recipes.json')) {
      if (raw is! String) {
        throw BalanceException('recipes.json: method names must be strings, '
            'got $raw');
      }
      methods.add(raw);
    }
    if (methods.isEmpty) {
      throw BalanceException('recipes.json: must define at least one method');
    }
    final recipes = <RecipeDef>[];
    for (final raw in _reqList(recipesJson, 'recipes', 'recipes.json')) {
      final m = _reqMap(raw, 'recipes.json');
      final a = _reqInt(m, 'mat_a', 'recipes.json');
      final b = _reqInt(m, 'mat_b', 'recipes.json');
      final methodName = _reqStr(m, 'method', 'recipes.json');
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
      final basePrice = _rangedInt(m, 'base_price', 'recipes.json');
      recipes.add(RecipeDef(
        id: _reqInt(m, 'id', 'recipes.json'),
        name: _reqStr(m, 'name', 'recipes.json'),
        matA: a <= b ? a : b,
        matB: a <= b ? b : a,
        method: method,
        basePrice: basePrice,
        invention: _reqBool(m, 'invention', 'recipes.json'),
        band: band,
        category:
            m.containsKey('category') ? _reqStr(m, 'category', 'recipes.json') : '',
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
    for (final raw in _reqList(ranksJson, 'ranks', 'ranks.json')) {
      final m = _reqMap(raw, 'ranks.json');
      ranks.add(RankDef(
        id: _reqInt(m, 'id', 'ranks.json'),
        name: _reqStr(m, 'name', 'ranks.json'),
        minAssets: _rangedInt(m, 'min_assets', 'ranks.json'),
        minFame: _rangedInt(m, 'min_fame', 'ranks.json'),
        minRecipes: _rangedInt(m, 'min_recipes', 'ranks.json'),
        minEmployees: _rangedInt(m, 'min_employees', 'ranks.json'),
        weeklyFixedCost: _rangedInt(m, 'weekly_fixed_cost', 'ranks.json'),
        taxBp: _rangedInt(m, 'tax_bp', 'ranks.json', max: 10000), // <=100%
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

    final events = parseEvents(eventsJson);
    // Validate effect references against the (already-built) content.
    for (final e in events) {
      for (final c in e.choices) {
        for (final ef in c.effects) {
          final bad = switch (ef.type) {
            'grant_recipe' => ef.refId < 0 || ef.refId >= recipes.length,
            'material' => ef.refId < 0 || ef.refId >= materials.length,
            'product' => ef.refId < 0 || ef.refId >= recipes.length,
            _ => false,
          };
          if (bad) {
            throw BalanceException(
                'events.json: effect "${ef.type}" ref ${ef.refId} out of range '
                '(event ${e.id})');
          }
        }
      }
    }

    final unlocks = _parseUnlocks(unlocksJson);
    final market = _parseMarket(marketJson, recipes);

    // Content hash covers events/unlocks/market ONLY when present, so a world
    // without them (headless) keeps the exact pre-feature hash (audit A-D1).
    final hashInput = <String, dynamic>{
      'economy': economyJson,
      'materials': materialsJson,
      'recipes': recipesJson,
      'ranks': ranksJson,
    };
    if (events.isNotEmpty) hashInput['events'] = eventsJson;
    if (unlocks.isNotEmpty) hashInput['unlocks'] = unlocksJson;
    if (market != null) hashInput['market'] = marketJson;
    final contentHash = hashHex(fnv1a64(canonicalJson(hashInput)));

    return Balance._(
      economy: economy,
      materials: materials,
      recipes: recipes,
      ranks: ranks,
      methods: methods,
      events: events,
      unlocks: unlocks,
      market: market,
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
