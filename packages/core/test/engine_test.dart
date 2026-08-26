import 'package:isekai_core/isekai_core.dart';
import 'package:test/test.dart';

Balance _balance({int startFunds = 100, int fixedCost = 0, int grace = 2}) =>
    Balance.fromJsonMaps(
      economyJson: {
        'schema_version': 1,
        'start_funds': startFunds,
        'lifespan_weeks': 50,
        'bankruptcy_grace_weeks': grace,
        'invention_cash_mult_x100': 2500,
        'invention_fame_mult_x100': 250,
        'fame_per_sales_g': 100,
        'wage_lv1': 8,
        'hire_cost': 20,
        'artisan_output_per_week': 3,
        'base_capacity_per_week': 2,
        'base_demand_x100': 100,
        'demand_per_fame_x100': 4,
        'rank_up_fame_bonus': 50,
        'max_employees': 30,
      },
      materialsJson: {
        'schema_version': 1,
        'materials': [
          {'id': 0, 'name': 'wheat', 'cost': 2},
          {'id': 1, 'name': 'egg', 'cost': 3},
        ],
      },
      recipesJson: {
        'schema_version': 1,
        'methods': ['cooling'],
        'recipes': [
          {
            'id': 0,
            'name': 'pudding',
            'mat_a': 0,
            'mat_b': 1,
            'method': 'cooling',
            'base_price': 12,
            'invention': true,
            'band': 1,
          },
          {
            'id': 1,
            'name': 'secret',
            'mat_a': 1,
            'mat_b': 1,
            'method': 'cooling',
            'base_price': 30,
            'invention': false,
            'band': 2,
          },
        ],
      },
      ranksJson: {
        'schema_version': 1,
        'ranks': [
          {
            'id': 0,
            'name': 'peddler',
            'min_assets': 0,
            'min_fame': 0,
            'min_recipes': 0,
            'min_employees': 0,
            'weekly_fixed_cost': fixedCost,
            'tax_bp': 0,
            'enabled': true,
          },
          {
            'id': 1,
            'name': 'stall',
            'min_assets': 300,
            'min_fame': 25,
            'min_recipes': 1,
            'min_employees': 0,
            'weekly_fixed_cost': fixedCost,
            'tax_bp': 0,
            'enabled': true,
          },
        ],
      },
    );

void main() {
  test('develop discovers pudding and pays invention bonus', () {
    final b = _balance();
    final s = GameState.initial(b, 1);
    Engine(b).tick(s, [
      OrderMaterial(0, 1), // -2G
      OrderMaterial(1, 1), // -3G
      Develop(0, 1, 0), // +12*25=300G, +12*2.5=30 fame
    ]);
    expect(s.discovered[0], isTrue);
    expect(s.discoveries, 1);
    expect(s.inventions, 1);
    expect(s.funds, 100 - 2 - 3 + 300);
    expect(s.fame, 30 + 50); // invention fame + rank-up bonus (395G/30fame)
    expect(s.rank, 1); // thresholds met in the same tick
  });

  test('band 2 recipe is not discoverable in life 1', () {
    final b = _balance();
    final s = GameState.initial(b, 1);
    Engine(b).tick(s, [OrderMaterial(1, 2), Develop(1, 1, 0)]);
    expect(s.discovered[1], isFalse);
    // materials are still consumed by the experiment
    expect(s.materialStock[1], 0);
  });

  test('produce clamps to capacity and materials, then sells', () {
    final b = _balance();
    final s = GameState.initial(b, 1);
    final engine = Engine(b);
    engine.tick(s, [OrderMaterial(0, 1), OrderMaterial(1, 1), Develop(0, 1, 0)]);
    final fundsBefore = s.funds;
    // capacity is 2/week with no employees; order enough for 5.
    engine.tick(s, [OrderMaterial(0, 5), OrderMaterial(1, 5), Produce(0, 5)]);
    // 2 produced; demand >= 2 given fame 80 → both sell at 12G.
    expect(s.productStock[0], 0);
    expect(s.totalRevenue, 24);
    expect(s.funds, fundsBefore - 5 * 2 - 5 * 3 + 24);
    expect(s.materialStock[0], 3);
    expect(s.materialStock[1], 3);
  });

  test('bankruptcy after grace weeks of negative funds', () {
    final b = _balance(startFunds: 10, fixedCost: 30, grace: 2);
    final s = GameState.initial(b, 1);
    final engine = Engine(b);
    engine.tick(s, []); // funds 10-30 = -20, streak 1
    expect(s.alive, isTrue);
    engine.tick(s, []); // streak 2 → dead
    expect(s.alive, isFalse);
    expect(s.endReason, 'bankrupt');
  });

  test('life ends at lifespan', () {
    final b = _balance();
    final s = GameState.initial(b, 1);
    final engine = Engine(b);
    while (s.alive) {
      engine.tick(s, []);
    }
    expect(s.week, 50);
    expect(s.endReason, 'lifespan');
  });

  test('grant adds funds (external inflow path)', () {
    final b = _balance();
    final s = GameState.initial(b, 1);
    Engine(b).tick(s, [Grant(500, 'offline_reward')]);
    expect(s.funds, 600);
  });

  test('extreme fame stays clamped, no int64 wrap (Critical #2)', () {
    final b = _balance();
    final s = GameState.initial(b, 1);
    final engine = Engine(b);
    engine.tick(s, [OrderMaterial(0, 1), OrderMaterial(1, 1), Develop(0, 1, 0)]);
    s.fame = gameValueCap; // pin fame at the ceiling
    for (var i = 0; i < 5; i++) {
      engine.tick(
          s, [OrderMaterial(0, 100), OrderMaterial(1, 100), Produce(0, 100)]);
      expect(s.fame, lessThanOrEqualTo(gameValueCap));
      expect(s.fame, greaterThanOrEqualTo(0)); // never wrapped negative
      expect(s.funds, inInclusiveRange(-gameValueCap, gameValueCap));
      expect(s.totalRevenue, inInclusiveRange(0, gameValueCap));
    }
  });

  test('huge grant is clamped, not wrapped', () {
    final b = _balance();
    final s = GameState.initial(b, 1);
    Engine(b).tick(s, [Grant(gameValueCap * 2, 'exploit_attempt')]);
    expect(s.funds, gameValueCap);
  });

  test('sales are capped by the shared demand pool, not per product', () {
    // Two products, both stocked well beyond the weekly pool. Total sales must
    // equal the pool — NOT pool × number-of-products (the old pseudo-infinite
    // bug). base_demand_x100=100 → pool≈1/wk at fame 0 (×jitter 0.95..1.05).
    final b = _balance();
    final s = GameState.initial(b, 1);
    final engine = Engine(b);
    // Discover both recipes (pudding id0 band1; secret id1 is band2 → bump).
    s.allowedBandMax = 2;
    engine.tick(s, [OrderMaterial(0, 1), OrderMaterial(1, 1), Develop(0, 1, 0)]);
    engine.tick(s, [OrderMaterial(1, 2), Develop(1, 1, 0)]);
    expect(s.discovered[0], isTrue);
    expect(s.discovered[1], isTrue);
    // Flood both product stocks directly, then run one sales tick with no
    // production commands so only existing stock can move.
    s.productStock[0] = 100;
    s.productStock[1] = 100;
    final soldBefore = s.productStock[0] + s.productStock[1];
    engine.tick(s, []);
    final soldAfter = s.productStock[0] + s.productStock[1];
    final totalSold = soldBefore - soldAfter;
    // Pool at fame≈small is tiny; total sold across BOTH products stays within
    // a handful of units, never ~200.
    expect(totalSold, lessThan(20),
        reason: 'shared pool must cap total sales, got $totalSold');
  });
}
