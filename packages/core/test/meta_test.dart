import 'package:isekai_core/isekai_core.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Controlled balance with a small unlock tree for exact fromMeta/purchase
/// asserts. start_funds 1000 so multipliers are easy to read.
Balance _b() => Balance.fromJsonMaps(
      economyJson: {
        'schema_version': 1,
        'start_funds': 1000,
        'lifespan_weeks': 100,
        'bankruptcy_grace_weeks': 4,
        'invention_cash_mult_x100': 2500,
        'invention_fame_mult_x100': 250,
        'fame_per_sales_g': 100,
        'wage_lv1': 8,
        'hire_cost': 20,
        'artisan_output_per_week': 10,
        'base_capacity_per_week': 10,
        'base_demand_x100': 1000,
        'demand_per_fame_x100': 4,
        'rank_up_fame_bonus': 50,
        'max_employees': 30,
        'equip_max_level': 20,
        'quality_mult_x100': [100, 130, 170],
      },
      materialsJson: {
        'schema_version': 1,
        'materials': [{'id': 0, 'name': 'w', 'cost': 1}],
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
          {'id': 0, 'name': 'r0', 'min_assets': 0, 'min_fame': 0,
              'min_recipes': 0, 'min_employees': 0, 'weekly_fixed_cost': 0,
              'tax_bp': 0, 'enabled': true},
          {'id': 1, 'name': 'r1', 'min_assets': 2000, 'min_fame': 0,
              'min_recipes': 0, 'min_employees': 0, 'weekly_fixed_cost': 0,
              'tax_bp': 0, 'enabled': true},
        ],
      },
      unlocksJson: {
        'schema_version': 1,
        'unlocks': [
          {'id': 0, 'key': 's1', 'name': 'S1', 'desc': '', 'cost': 400,
              'tier': 'free', 'requires': [], 'mod_type': 'start_funds',
              'mod_value': 500, 'infinite': false},
          {'id': 1, 'key': 's2', 'name': 'S2', 'desc': '', 'cost': 800,
              'tier': 'free', 'requires': [0], 'mod_type': 'start_funds',
              'mod_value': 2000, 'infinite': false},
          {'id': 2, 'key': 'emp', 'name': 'Emp', 'desc': '', 'cost': 600,
              'tier': 'free', 'requires': [], 'mod_type': 'start_employee',
              'mod_value': 1, 'infinite': false},
          {'id': 3, 'key': 'eq', 'name': 'Eq', 'desc': '', 'cost': 500,
              'tier': 'free', 'requires': [], 'mod_type': 'equip_start_level',
              'mod_value': 2, 'infinite': false},
          {'id': 4, 'key': 'rk', 'name': 'Rank', 'desc': '', 'cost': 0,
              'tier': 'auto', 'requires': [], 'mod_type': 'start_rank',
              'mod_value': 1, 'infinite': false},
          {'id': 5, 'key': 'pct', 'name': 'Pct', 'desc': '', 'cost': 1000,
              'tier': 'full', 'requires': [], 'mod_type': 'start_funds_pct',
              'mod_value': 10, 'infinite': true},
          {'id': 6, 'key': 'race', 'name': 'Race', 'desc': '', 'cost': 300,
              'tier': 'full', 'requires': [], 'mod_type': 'race_dwarf',
              'mod_value': 1, 'infinite': false}, // feature-gated (no effect yet)
          {'id': 7, 'key': 'prod', 'name': 'Prod', 'desc': '', 'cost': 400,
              'tier': 'free', 'requires': [], 'mod_type': 'production_bonus',
              'mod_value': 10, 'infinite': false},
          {'id': 8, 'key': 'sales', 'name': 'Sales', 'desc': '', 'cost': 400,
              'tier': 'free', 'requires': [], 'mod_type': 'sales_bonus',
              'mod_value': 5, 'infinite': false},
          {'id': 9, 'key': 'order', 'name': 'Order', 'desc': '', 'cost': 400,
              'tier': 'free', 'requires': [], 'mod_type': 'order_discount',
              'mod_value': 5, 'infinite': false},
        ],
      },
    );

MetaState _meta({int soulPoints = 0, List<int>? levels}) => MetaState.raw(
      soulPoints: soulPoints,
      lifetimeBest: 0,
      tutorialDone: false,
      unlockLevels: levels ?? <int>[],
    );

void main() {
  test('the real unlocks.json loads 24 nodes with sequential ids', () {
    final b = testBalanceFull();
    expect(b.unlocks.length, 24);
    for (var i = 0; i < b.unlocks.length; i++) {
      expect(b.unlocks[i].id, i);
    }
    // Tier split (§8.4): 11 free / 12 full / 1 auto. #16 auto-order is FREE.
    expect(b.unlocks.where((u) => u.tier == 'free').length, 11);
    expect(b.unlocks.where((u) => u.tier == 'full').length, 12);
    expect(b.unlocks.where((u) => u.tier == 'auto').length, 1);
    final autoOrder = b.unlocks.firstWhere((u) => u.key == 'auto_order');
    expect(autoOrder.tier, 'free');
  });

  test('content hash includes unlocks only when present', () {
    final withU = _b().contentHash;
    final noU = Balance.fromJsonMaps(
      economyJson: {
        'schema_version': 1, 'start_funds': 1000, 'lifespan_weeks': 100,
        'bankruptcy_grace_weeks': 4, 'invention_cash_mult_x100': 2500,
        'invention_fame_mult_x100': 250, 'fame_per_sales_g': 100, 'wage_lv1': 8,
        'hire_cost': 20, 'artisan_output_per_week': 10,
        'base_capacity_per_week': 10, 'base_demand_x100': 1000,
        'demand_per_fame_x100': 4, 'rank_up_fame_bonus': 50, 'max_employees': 30,
      },
      materialsJson: {'schema_version': 1, 'materials': [{'id': 0, 'name': 'w', 'cost': 1}]},
      recipesJson: {'schema_version': 1, 'methods': ['h'], 'recipes': [
        {'id': 0, 'name': 'b', 'mat_a': 0, 'mat_b': 0, 'method': 'h',
            'base_price': 7, 'invention': false, 'band': 1}]},
      ranksJson: {'schema_version': 1, 'ranks': [
        {'id': 0, 'name': 'r', 'min_assets': 0, 'min_fame': 0, 'min_recipes': 0,
            'min_employees': 0, 'weekly_fixed_cost': 0, 'tax_bp': 0,
            'enabled': true}]},
    ).contentHash;
    expect(withU, isNot(noU));
  });

  test('fromMeta applies ADD before MULTIPLY (audit R5)', () {
    final b = _b(); // start_funds 1000
    // Own S1 (+500) and Pct (+10%): (1000 + 500) × 1.1 = 1650, not 1000×1.1+500.
    final meta = _meta(levels: [1, 0, 0, 0, 0, 1, 0]);
    final s = GameState.fromMeta(b, 1, meta);
    expect(s.funds, 1650);
  });

  test('fromMeta applies employee / equipment / rank start bonuses', () {
    final b = _b();
    final meta = _meta(levels: [0, 0, 1, 1, 1, 0, 0]); // emp, equip, rank
    final s = GameState.fromMeta(b, 1, meta);
    expect(s.employees, 1);
    expect(s.equipmentLevel, 2);
    expect(s.rank, 1);
  });

  test('fromMeta infinite node stacks by level', () {
    final b = _b();
    // Pct at level 3 → +30% → 1000 × 1.30 = 1300.
    final s = GameState.fromMeta(b, 1, _meta(levels: [0, 0, 0, 0, 0, 3, 0]));
    expect(s.funds, 1300);
  });

  test('fromMeta with no meta equals initial (byte identity)', () {
    final b = _b();
    final fresh = GameState.fromMeta(b, 7, _meta());
    final init = GameState.initial(b, 7);
    expect(fresh.stateHash(), init.stateHash());
  });

  test('feature-gated mod types do not alter the start state', () {
    final b = _b();
    // Own the race_dwarf node (id 6) — feature-gated, no effect yet.
    final s = GameState.fromMeta(b, 1, _meta(levels: [0, 0, 0, 0, 0, 0, 1]));
    expect(s.stateHash(), GameState.initial(b, 1).stateHash());
  });

  test('fromMeta wires the economy multipliers (production/sales/order)', () {
    final b = _b();
    // Own prod(id7 +10%), sales(id8 +5%), order(id9 -5%).
    final s = GameState.fromMeta(
        b, 1, _meta(levels: [0, 0, 0, 0, 0, 0, 0, 1, 1, 1]));
    expect(s.productionBonusX100, 10);
    expect(s.salesBonusX100, 5);
    expect(s.orderDiscountX100, 5);
  });

  test('feature-gated unlocks cannot be purchased yet (景表法)', () {
    final b = _b();
    final meta = _meta(soulPoints: 9000)..ensureUnlockSlots(b.unlocks.length);
    // id6 = race_dwarf (feature-gated) → refused even with points to spare.
    expect(tryPurchaseUnlock(meta, b.unlocks, 6), isFalse);
    expect(meta.soulPoints, 9000);
    // id7 = production_bonus (functional) → allowed.
    expect(tryPurchaseUnlock(meta, b.unlocks, 7), isTrue);
    expect(isUnlockFunctional(b.unlocks[6]), isFalse);
    expect(isUnlockFunctional(b.unlocks[7]), isTrue);
  });

  test('purchase enforces prerequisites, cost, and one-shot', () {
    final b = _b();
    final meta = _meta(soulPoints: 5000)..ensureUnlockSlots(b.unlocks.length);
    // S2 (id1) requires S1 (id0) → blocked until S1 owned.
    expect(tryPurchaseUnlock(meta, b.unlocks, 1), isFalse);
    expect(tryPurchaseUnlock(meta, b.unlocks, 0), isTrue); // S1: -400
    expect(meta.soulPoints, 4600);
    expect(tryPurchaseUnlock(meta, b.unlocks, 0), isFalse); // already owned
    expect(tryPurchaseUnlock(meta, b.unlocks, 1), isTrue); // now allowed: -800
    expect(meta.soulPoints, 3800);
    expect(meta.isUnlocked(1), isTrue);
  });

  test('purchase fails when soul points are short', () {
    final b = _b();
    final meta = _meta(soulPoints: 100)..ensureUnlockSlots(b.unlocks.length);
    expect(tryPurchaseUnlock(meta, b.unlocks, 0), isFalse); // costs 400
    expect(meta.soulPoints, 100);
  });

  test('infinite node cost grows ×1.6 and is repeatable', () {
    final b = _b();
    final pct = b.unlocks[5];
    expect(unlockCostForLevel(pct, 0), 1000);
    expect(unlockCostForLevel(pct, 1), 1600);
    expect(unlockCostForLevel(pct, 2), 2560);
    final meta = _meta(soulPoints: 10000)..ensureUnlockSlots(b.unlocks.length);
    expect(tryPurchaseUnlock(meta, b.unlocks, 5), isTrue); // -1000
    expect(tryPurchaseUnlock(meta, b.unlocks, 5), isTrue); // -1600 (repeatable)
    expect(meta.levelOf(5), 2);
    expect(meta.soulPoints, 10000 - 1000 - 1600);
  });

  test('MetaView exposes tier filtering + queries (MetaReader)', () {
    final b = _b();
    final meta = _meta()..ensureUnlockSlots(b.unlocks.length);
    meta.unlockLevels[0] = 1;
    final MetaReader r = MetaView(meta, b.unlocks);
    expect(r.isUnlocked(0), isTrue);
    expect(r.isUnlocked(1), isFalse);
    expect(r.unlocksOfTier('auto').map((u) => u.id), [4]);
    expect(r.unlocksOfTier('full').map((u) => u.id), [5, 6]);
  });

  test('fromMeta-applied state replays bit-identically', () {
    final b = _b();
    final meta = _meta(levels: [1, 1, 1, 1, 1, 2, 0]);
    final a = GameState.fromMeta(b, 42, meta);
    final c = GameState.fromMeta(b, 42, meta);
    final engine = Engine(b);
    for (var i = 0; i < 30; i++) {
      engine.tick(a, []);
      engine.tick(c, []);
    }
    expect(a.stateHash(), c.stateHash());
  });
}
