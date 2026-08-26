import 'package:isekai_core/isekai_core.dart';
import 'package:test/test.dart';

/// Controlled balance with 2 categories + a market. Season 0 (春) boosts food
/// ×2 and leaves tool at ×1; the recipes are otherwise identical so a demand
/// difference is purely the weighting.
Balance _b({Map<String, dynamic>? market}) => Balance.fromJsonMaps(
      economyJson: {
        'schema_version': 1, 'start_funds': 100, 'lifespan_weeks': 100,
        'bankruptcy_grace_weeks': 4, 'invention_cash_mult_x100': 2500,
        'invention_fame_mult_x100': 250, 'fame_per_sales_g': 100, 'wage_lv1': 8,
        'hire_cost': 20, 'artisan_output_per_week': 10,
        'base_capacity_per_week': 1000, 'base_demand_x100': 60000,
        'demand_per_fame_x100': 4, 'rank_up_fame_bonus': 50, 'max_employees': 30,
      },
      materialsJson: {
        'schema_version': 1,
        'materials': [{'id': 0, 'name': 'w', 'cost': 1}, {'id': 1, 'name': 'x', 'cost': 1}],
      },
      recipesJson: {
        'schema_version': 1, 'methods': ['h'],
        'recipes': [
          {'id': 0, 'name': 'bread', 'mat_a': 0, 'mat_b': 0, 'method': 'h',
              'base_price': 10, 'invention': false, 'band': 1, 'category': 'food'},
          {'id': 1, 'name': 'tool', 'mat_a': 1, 'mat_b': 1, 'method': 'h',
              'base_price': 10, 'invention': false, 'band': 1, 'category': 'tool'},
        ],
      },
      ranksJson: {
        'schema_version': 1,
        'ranks': [{'id': 0, 'name': 'r', 'min_assets': 0, 'min_fame': 0,
            'min_recipes': 0, 'min_employees': 0, 'weekly_fixed_cost': 0,
            'tax_bp': 0, 'enabled': true}],
      },
      marketJson: market,
    );

const _market = {
  'schema_version': 1,
  'categories': ['food', 'tool'],
  'season_category_mult': {
    'food': [200, 100, 100, 100], // 春 doubles food demand
    'tool': [100, 100, 100, 100],
  },
  'trend': {
    'avg_interval_weeks': 20, 'forecast_weeks': 4,
    'min_active_weeks': 8, 'max_active_weeks': 8, 'mult_min_x100': 300,
    'mult_max_x100': 300,
  },
};

void main() {
  test('no market → uniform water-fill (byte-identical to pre-v0.9)', () {
    final noM = _b();
    expect(noM.market, isNull);
    // Two identical-price products, equal stock, huge pool but capacity-free.
    final s = GameState.initial(noM, 1)
      ..discovered[0] = true
      ..discovered[1] = true
      ..productStock[0] = 100
      ..productStock[1] = 100;
    final r = Engine(noM).tick(s, []);
    // Equal weights → each sells the same (fair share).
    expect(100 - s.productStock[0], 100 - s.productStock[1]);
    expect(r.weeklySold, greaterThan(0));
  });

  test('season multiplier weights demand by category (§7)', () {
    final b = _b(market: _market);
    expect(b.market, isNotNull);
    // week 0 = 春 → food ×2. Pool < total stock so weighting bites.
    final s = GameState.initial(b, 1)
      ..discovered[0] = true
      ..discovered[1] = true
      ..productStock[0] = 1000 // food
      ..productStock[1] = 1000; // tool
    Engine(b).tick(s, []);
    final foodSold = 1000 - s.productStock[0];
    final toolSold = 1000 - s.productStock[1];
    expect(foodSold, greaterThan(toolSold)); // spring boosts food
  });

  test('a forced trend multiplies its category, then ends', () {
    final b = _b(market: _market);
    final s = GameState.initial(b, 1)
      ..discovered[0] = true
      ..discovered[1] = true
      ..productStock[0] = 1000
      ..productStock[1] = 1000
      // Force a live trend on tool (id category 1). forecast 0 = active now.
      ..trendCategory = 1
      ..trendForecastWeeks = 0
      ..trendActiveWeeks = 1
      ..trendMultX100 = 400;
    Engine(b).tick(s, []);
    final toolSold = 1000 - s.productStock[1];
    final foodSold = 1000 - s.productStock[0];
    // tool ×4 (trend) beats food ×2 (season) → tool sells more.
    expect(toolSold, greaterThan(foodSold));
    // The trend consumed its last active week → cleared.
    expect(s.trendActiveWeeks, 0);
    expect(s.trendCategory, -1);
  });

  test('trends eventually onset and are announced then active (deterministic)',
      () {
    final b = _b(market: _market);
    final s = GameState.initial(b, 7)..discovered[0] = true;
    final engine = Engine(b);
    var sawForecast = false, sawActive = false;
    for (var i = 0; i < 300 && s.alive; i++) {
      final r = engine.tick(s, [
        Produce(0, 5),
        OrderMaterial(0, 10),
      ]);
      if (r.trendOnset) sawForecast = true;
      if (s.trendForecastWeeks == 0 && s.trendActiveWeeks > 0) sawActive = true;
    }
    expect(sawForecast, isTrue); // a trend was announced
    expect(sawActive, isTrue); // and later went live
  });

  test('market state serializes only when a trend is present', () {
    final b = _b(market: _market);
    final s = GameState.initial(b, 1);
    expect(s.toJson().containsKey('trend_cat'), isFalse); // default omitted
    s
      ..trendCategory = 1
      ..trendActiveWeeks = 5
      ..trendMultX100 = 300;
    final back = GameState.fromJson(s.toJson());
    expect(back.trendCategory, 1);
    expect(back.trendActiveWeeks, 5);
    expect(back.trendMultX100, 300);
  });

  test('market rejects a recipe category outside its category list', () {
    expect(
      () => _b(market: {
        'schema_version': 1,
        'categories': ['food'], // missing 'tool'
        'season_category_mult': {'food': [100, 100, 100, 100]},
        'trend': {'avg_interval_weeks': 20, 'forecast_weeks': 4,
            'min_active_weeks': 8, 'max_active_weeks': 8,
            'mult_min_x100': 200, 'mult_max_x100': 300},
      }),
      throwsA(isA<BalanceException>()),
    );
  });
}
