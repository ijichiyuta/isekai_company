import 'dart:convert';

import 'package:isekai_core/isekai_core.dart';
import 'package:test/test.dart';

// A minimal valid balance set; tests mutate a deep copy to inject faults and
// assert every fault surfaces as BalanceException (never a raw TypeError).
Map<String, dynamic> get _economy => {
      'schema_version': 1,
      'start_funds': 100,
      'lifespan_weeks': 2880,
      'bankruptcy_grace_weeks': 4,
      'invention_cash_mult_x100': 2500,
      'invention_fame_mult_x100': 250,
      'fame_per_sales_g': 20,
      'wage_lv1': 8,
      'hire_cost': 20,
      'artisan_output_per_week': 3,
      'base_capacity_per_week': 2,
      'base_demand_x100': 300,
      'demand_per_fame_x100': 4,
      'rank_up_fame_bonus': 50,
      'max_employees': 30,
    };

Map<String, dynamic> get _materials => {
      'schema_version': 1,
      'materials': [
        {'id': 0, 'name': 'wheat', 'cost': 2},
        {'id': 1, 'name': 'egg', 'cost': 3},
      ],
    };

Map<String, dynamic> get _recipes => {
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
      ],
    };

Map<String, dynamic> get _ranks => {
      'schema_version': 1,
      'ranks': [
        {
          'id': 0,
          'name': 'peddler',
          'min_assets': 0,
          'min_fame': 0,
          'min_recipes': 0,
          'min_employees': 0,
          'weekly_fixed_cost': 0,
          'tax_bp': 0,
          'enabled': true,
        },
      ],
    };

Balance _build({
  Map<String, dynamic>? economy,
  Map<String, dynamic>? materials,
  Map<String, dynamic>? recipes,
  Map<String, dynamic>? ranks,
}) =>
    Balance.fromJsonMaps(
      economyJson: economy ?? _economy,
      materialsJson: materials ?? _materials,
      recipesJson: recipes ?? _recipes,
      ranksJson: ranks ?? _ranks,
    );

/// Deep copy so per-test mutations don't leak.
Map<String, dynamic> _clone(Map<String, dynamic> m) =>
    jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

void main() {
  test('the baseline balance builds', () {
    final b = _build();
    expect(b.recipes.single.name, 'pudding');
    expect(b.contentHash, isNotEmpty);
  });

  group('malformed input surfaces as BalanceException, never a raw TypeError',
      () {
    void expectBalanceError(void Function() f) =>
        expect(f, throwsA(isA<BalanceException>()));

    test('methods key missing', () {
      final r = _clone(_recipes)..remove('methods');
      expectBalanceError(() => _build(recipes: r));
    });

    test('recipes key missing', () {
      final r = _clone(_recipes)..remove('recipes');
      expectBalanceError(() => _build(recipes: r));
    });

    test('materials is not a list', () {
      final m = _clone(_materials)..['materials'] = 'oops';
      expectBalanceError(() => _build(materials: m));
    });

    test('a recipe entry is not an object', () {
      final r = _clone(_recipes)..['recipes'] = [42];
      expectBalanceError(() => _build(recipes: r));
    });

    test('non-string method element is rejected (lazy-cast hole)', () {
      // ['cooling', 42] used to build fine because .cast<String>() is lazy and
      // indexOf('cooling') matched index 0 without touching element 1.
      final r = _clone(_recipes)..['methods'] = ['cooling', 42];
      expectBalanceError(() => _build(recipes: r));
    });

    test('recipe.method wrong type', () {
      final r = _clone(_recipes);
      (r['recipes'] as List)[0]['method'] = 7;
      expectBalanceError(() => _build(recipes: r));
    });
  });

  group('range validation (economy/ranks)', () {
    test('negative start_funds rejected', () {
      final e = _clone(_economy)..['start_funds'] = -500;
      expect(() => _build(economy: e), throwsA(isA<BalanceException>()));
    });

    test('lifespan_weeks must be >= 1', () {
      final e = _clone(_economy)..['lifespan_weeks'] = 0;
      expect(() => _build(economy: e), throwsA(isA<BalanceException>()));
    });

    test('fame_per_sales_g must be >= 1 (it is a divisor)', () {
      final e = _clone(_economy)..['fame_per_sales_g'] = 0;
      expect(() => _build(economy: e), throwsA(isA<BalanceException>()));
    });

    test('negative wage rejected', () {
      final e = _clone(_economy)..['wage_lv1'] = -7;
      expect(() => _build(economy: e), throwsA(isA<BalanceException>()));
    });

    test('tax_bp above 100% rejected', () {
      final r = _clone(_ranks);
      (r['ranks'] as List)[0]['tax_bp'] = 20000;
      expect(() => _build(ranks: r), throwsA(isA<BalanceException>()));
    });

    test('negative min_recipes rejected', () {
      final r = _clone(_ranks);
      (r['ranks'] as List)[0]['min_recipes'] = -5;
      expect(() => _build(ranks: r), throwsA(isA<BalanceException>()));
    });
  });
}
