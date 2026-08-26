import 'package:isekai_core/isekai_core.dart';
import 'package:test/test.dart';

/// M3 P1 economy drivers: equipment (capacity ×), quality (price ×), invention
/// premium (C-2). Controlled inline balance with round numbers for exact asserts.
Balance _b({Map<String, dynamic>? econ}) => Balance.fromJsonMaps(
      economyJson: {
        'schema_version': 1,
        'start_funds': 100,
        'lifespan_weeks': 100,
        'bankruptcy_grace_weeks': 4,
        'invention_cash_mult_x100': 2500,
        'invention_fame_mult_x100': 250,
        'fame_per_sales_g': 100,
        'wage_lv1': 8,
        'hire_cost': 20,
        'artisan_output_per_week': 10,
        'base_capacity_per_week': 10,
        'base_demand_x100': 100000, // huge pool → capacity is the constraint
        'demand_per_fame_x100': 4,
        'rank_up_fame_bonus': 50,
        'max_employees': 30,
        'equip_cost_base': 1000,
        'equip_cost_mult_x100': 200, // each level ×2 the previous
        'equip_step_x100': 50, // +50% of base capacity per level
        'equip_max_level': 3,
        'quality_cost_base': 2000,
        'quality_cost_mult_x100': 150,
        'quality_mult_x100': [100, 200, 300], // ×2, ×3
        'invention_price_premium_x100': 200, // inventions ×2
        ...?econ,
      },
      materialsJson: {
        'schema_version': 1,
        'materials': [
          {'id': 0, 'name': 'w', 'cost': 1},
          {'id': 1, 'name': 'x', 'cost': 1},
        ],
      },
      recipesJson: {
        'schema_version': 1,
        'methods': ['h'],
        'recipes': [
          {'id': 0, 'name': 'staple', 'mat_a': 0, 'mat_b': 0, 'method': 'h',
              'base_price': 10, 'invention': false, 'band': 1},
          {'id': 1, 'name': 'gadget', 'mat_a': 0, 'mat_b': 1, 'method': 'h',
              'base_price': 10, 'invention': true, 'band': 1},
        ],
      },
      ranksJson: {
        'schema_version': 1,
        'ranks': [
          {'id': 0, 'name': 'p', 'min_assets': 0, 'min_fame': 0,
              'min_recipes': 0, 'min_employees': 0, 'weekly_fixed_cost': 0,
              'tax_bp': 0, 'enabled': true},
        ],
      },
    );

void main() {
  test('equipment upgrade: geometric cost, capped at max level', () {
    final b = _b();
    final e = Engine(b);
    final s = GameState.initial(b, 1)..funds = 100000;
    // Level 0→1 costs equip_cost_base (1000). No revenue/costs at rank 0.
    e.tick(s, [UpgradeEquipment()]);
    expect(s.equipmentLevel, 1);
    expect(s.funds, 99000);
    // Level 1→2 costs 1000×200/100 = 2000.
    e.tick(s, [UpgradeEquipment()]);
    expect(s.equipmentLevel, 2);
    expect(s.funds, 97000);
    // 2→3 costs 4000; then capped at equip_max_level (3).
    e.tick(s, [UpgradeEquipment()]);
    e.tick(s, [UpgradeEquipment()]);
    expect(s.equipmentLevel, 3);
    expect(s.funds, 93000); // last upgrade was a no-op
  });

  test('equipment scales weekly production capacity', () {
    final b = _b(econ: {'base_demand_x100': 0}); // nothing sells → stock = made
    final e = Engine(b);
    final s = GameState.initial(b, 1)
      ..funds = 1000000
      ..discovered[0] = true
      ..materialStock[0] = 100000;
    // Level 0 → capacity = base_capacity 10.
    e.tick(s, [Produce(0, 1000)]);
    expect(s.productStock[0], 10);
    // Level 2 → ×(100+2×50)/100 = ×2 → capacity 20.
    s
      ..equipmentLevel = 2
      ..productStock[0] = 0;
    e.tick(s, [Produce(0, 1000)]);
    expect(s.productStock[0], 20);
  });

  test('quality star scales sale price', () {
    final b = _b();
    final e = Engine(b);
    final s = GameState.initial(b, 1)
      ..funds = 1000000
      ..discovered[0] = true
      ..materialStock[0] = 1000;
    final r0 = e.tick(s, [Produce(0, 5)]);
    expect(r0.weeklyRevenue, 5 * 10); // quality 0 → base price 10
    s
      ..qualityStar = 1 // ×200/100
      ..productStock[0] = 0
      ..materialStock[0] = 1000;
    final r1 = e.tick(s, [Produce(0, 5)]);
    expect(r1.weeklyRevenue, 5 * 20);
  });

  test('inventions sell at the premium price (C-2)', () {
    final b = _b(); // premium ×200, gadget (id1) is an invention, price 10
    final e = Engine(b);
    final s = GameState.initial(b, 1)
      ..funds = 1000000
      ..discovered[1] = true
      ..materialStock[0] = 1000
      ..materialStock[1] = 1000;
    final r = e.tick(s, [Produce(1, 5)]);
    expect(r.weeklyRevenue, 5 * 20); // 10 × premium 200/100
  });

  test('quality caps at the mult-table end', () {
    final b = _b();
    final e = Engine(b);
    final s = GameState.initial(b, 1)..funds = 1 << 50;
    for (var i = 0; i < 10; i++) {
      e.tick(s, [ImproveQuality()]);
    }
    expect(s.qualityStar, 2); // quality_mult_x100 length 3 → max star 2
  });

  test('a balance without equip/quality keys is a no-op (byte identity)', () {
    final noKeys = Balance.fromJsonMaps(
      economyJson: {
        'schema_version': 1,
        'start_funds': 100,
        'lifespan_weeks': 100,
        'bankruptcy_grace_weeks': 4,
        'invention_cash_mult_x100': 2500,
        'invention_fame_mult_x100': 250,
        'fame_per_sales_g': 100,
        'wage_lv1': 8,
        'hire_cost': 20,
        'artisan_output_per_week': 3,
        'base_capacity_per_week': 2,
        'base_demand_x100': 300,
        'demand_per_fame_x100': 4,
        'rank_up_fame_bonus': 50,
        'max_employees': 30,
      },
      materialsJson: {
        'schema_version': 1,
        'materials': [{'id': 0, 'name': 'w', 'cost': 2}],
      },
      recipesJson: {
        'schema_version': 1,
        'methods': ['h'],
        'recipes': [
          {'id': 0, 'name': 'b', 'mat_a': 0, 'mat_b': 0, 'method': 'h',
              'base_price': 7, 'invention': false, 'band': 1},
        ],
      },
      ranksJson: {
        'schema_version': 1,
        'ranks': [
          {'id': 0, 'name': 'p', 'min_assets': 0, 'min_fame': 0,
              'min_recipes': 0, 'min_employees': 0, 'weekly_fixed_cost': 0,
              'tax_bp': 0, 'enabled': true},
        ],
      },
    );
    expect(noKeys.economy.equipMaxLevel, 0);
    expect(noKeys.economy.qualityMultX100, [100]);
    expect(noKeys.economy.inventionPricePremiumX100, 100);
    final e = Engine(noKeys);
    final s = GameState.initial(noKeys, 1)..funds = 100000;
    e.tick(s, [UpgradeEquipment(), ImproveQuality()]);
    expect(s.equipmentLevel, 0); // equipment disabled (max level 0)
    expect(s.qualityStar, 0); // quality disabled (table length 1)
    // Conditional serialization: the fields never appear (pre-M3 hash identity).
    expect(s.toJson().containsKey('equipment_level'), isFalse);
    expect(s.toJson().containsKey('quality_star'), isFalse);
  });

  test('new commands round-trip through JSON', () {
    expect(Command.fromJson(UpgradeEquipment().toJson()),
        isA<UpgradeEquipment>());
    expect(Command.fromJson(ImproveQuality().toJson()), isA<ImproveQuality>());
  });

  test('equip/quality state serializes only when non-default', () {
    final b = _b();
    final s = GameState.initial(b, 1)
      ..equipmentLevel = 2
      ..qualityStar = 1;
    final json = s.toJson();
    expect(json['equipment_level'], 2);
    expect(json['quality_star'], 1);
    final back = GameState.fromJson(json);
    expect(back.equipmentLevel, 2);
    expect(back.qualityStar, 1);
  });

  test('quality_mult_x100 validation', () {
    Balance mk(List<int> mult) => _b(econ: {'quality_mult_x100': mult});
    expect(() => mk([90, 100]), throwsA(isA<BalanceException>())); // [0]!=100
    expect(() => mk([100, 90]), throwsA(isA<BalanceException>())); // decreasing
    expect(mk([100, 150, 150]).economy.qualityMultX100, [100, 150, 150]); // ok
  });
}
