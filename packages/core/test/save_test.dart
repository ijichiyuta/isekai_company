import 'package:isekai_core/isekai_core.dart';
import 'package:test/test.dart';

Balance _balance() => Balance.fromJsonMaps(
      economyJson: {
        'schema_version': 1,
        'start_funds': 100,
        'lifespan_weeks': 20,
        'bankruptcy_grace_weeks': 4,
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
        ],
      },
      recipesJson: {
        'schema_version': 1,
        'methods': ['heating'],
        'recipes': [
          {
            'id': 0,
            'name': 'bread',
            'mat_a': 0,
            'mat_b': 0,
            'method': 'heating',
            'base_price': 7,
            'invention': false,
            'band': 1,
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
            'weekly_fixed_cost': 0,
            'tax_bp': 0,
            'enabled': true,
          },
        ],
      },
    );

void main() {
  test('save roundtrip preserves state hash', () {
    final b = _balance();
    final s = GameState.initial(b, 99);
    Engine(b).tick(s, [OrderMaterial(0, 2), Develop(0, 0, 0)]);
    final text = encodeSave(s, b);
    final restored = decodeSave(text, b);
    expect(restored.stateHash(), s.stateHash());
    expect(restored.week, s.week);
    expect(restored.rng.economy.drawCount, s.rng.economy.drawCount);
  });

  test('tampered save is rejected', () {
    final b = _balance();
    final s = GameState.initial(b, 99);
    final text = encodeSave(s, b);
    final tampered = text.replaceFirst('"funds":100', '"funds":999999');
    expect(tampered, isNot(text)); // guard: the substring must exist
    expect(() => decodeSave(tampered, b),
        throwsA(isA<SaveCorruptException>()));
  });

  test('unknown schema version is rejected', () {
    final b = _balance();
    final s = GameState.initial(b, 99);
    final text = encodeSave(s, b)
        .replaceFirst('"schema_version":1', '"schema_version":2');
    expect(() => decodeSave(text, b), throwsA(isA<SaveCorruptException>()));
  });
}
