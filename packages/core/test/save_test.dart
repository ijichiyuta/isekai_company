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

/// Reconstruct a well-formed doc with a valid checksum (the way encodeSave
/// does), so tests can craft edge-case documents that pass the checksum gate.
String _sealed(Map<String, dynamic> doc) {
  final d = Map<String, dynamic>.of(doc)..remove('checksum');
  d['checksum'] = hashHex(fnv1a64(canonicalJson(d)));
  return canonicalJson(d);
}

void main() {
  test('save roundtrip preserves state + meta', () {
    final b = _balance();
    final s = GameState.initial(b, 99);
    Engine(b).tick(s, [OrderMaterial(0, 2), Develop(0, 0, 0)]);
    final meta = MetaState.raw(
        soulPoints: 42, lifetimeBest: 7, tutorialDone: true, unlockLevels: [2]);
    final text = encodeSave(s, meta, b);
    final restored = decodeSave(text, b);
    expect(restored.state.stateHash(), s.stateHash());
    expect(restored.state.week, s.week);
    expect(restored.state.rng.economy.drawCount, s.rng.economy.drawCount);
    expect(restored.meta.soulPoints, 42);
    expect(restored.meta.lifetimeBest, 7);
    expect(restored.meta.tutorialDone, isTrue);
    expect(restored.meta.levelOf(0), 2);
  });

  test('tampered save is rejected', () {
    final b = _balance();
    final s = GameState.initial(b, 99);
    final text = encodeSave(s, MetaState.initial(), b);
    final tampered = text.replaceFirst('"funds":100', '"funds":999999');
    expect(tampered, isNot(text)); // guard: the substring must exist
    expect(() => decodeSave(tampered, b),
        throwsA(isA<SaveCorruptException>()));
  });

  test('tampered meta is caught by the checksum', () {
    final b = _balance();
    final s = GameState.initial(b, 99);
    final text = encodeSave(
        s, MetaState.raw(soulPoints: 5, lifetimeBest: 0, tutorialDone: false, unlockLevels: []), b);
    final tampered = text.replaceFirst('"soul_points":5', '"soul_points":99999');
    expect(tampered, isNot(text));
    expect(() => decodeSave(tampered, b), throwsA(isA<SaveCorruptException>()));
  });

  test('newer schema version is rejected', () {
    final b = _balance();
    // A well-formed doc from a hypothetical future version (valid checksum).
    final future = _sealed({
      'schema_version': saveSchemaVersion + 1,
      'balance_hash': b.contentHash,
      'state': GameState.initial(b, 1).toJson(),
      'meta': MetaState.initial().toJson(),
    });
    expect(() => decodeSave(future, b), throwsA(isA<SaveCorruptException>()));
  });

  test('tampered balance_hash is caught by the checksum', () {
    final b = _balance();
    final s = GameState.initial(b, 99);
    final text = encodeSave(s, MetaState.initial(), b);
    final hashStart = text.indexOf('"balance_hash":"') + 16;
    final orig = text[hashStart];
    final swapped = orig == 'a' ? 'b' : 'a';
    final tampered = text.replaceRange(hashStart, hashStart + 1, swapped);
    expect(tampered, isNot(text));
    expect(() => decodeSave(tampered, b), throwsA(isA<SaveCorruptException>()));
  });

  test('truncated JSON is a SaveCorruptException, not a raw crash', () {
    final b = _balance();
    final s = GameState.initial(b, 99);
    final text = encodeSave(s, MetaState.initial(), b);
    final cut = text.substring(0, text.length ~/ 2);
    expect(() => decodeSave(cut, b), throwsA(isA<SaveCorruptException>()));
  });

  test('non-object top level is a SaveCorruptException', () {
    final b = _balance();
    expect(() => decodeSave('[1,2,3]', b),
        throwsA(isA<SaveCorruptException>()));
    expect(() => decodeSave('42', b), throwsA(isA<SaveCorruptException>()));
  });

  test('missing state object is a SaveCorruptException (valid checksum)', () {
    final b = _balance();
    // A doc that passes the checksum + version + balance gates but has no state.
    final broken = _sealed({
      'schema_version': saveSchemaVersion,
      'balance_hash': b.contentHash,
      'meta': MetaState.initial().toJson(),
    });
    expect(() => decodeSave(broken, b), throwsA(isA<SaveCorruptException>()));
  });

  test('missing meta object is a SaveCorruptException (valid checksum)', () {
    final b = _balance();
    final broken = _sealed({
      'schema_version': saveSchemaVersion,
      'balance_hash': b.contentHash,
      'state': GameState.initial(b, 1).toJson(),
    });
    expect(() => decodeSave(broken, b), throwsA(isA<SaveCorruptException>()));
  });

  test('AC-15: a v1 (state-only) save migrates to v2 with default meta', () {
    // Craft a genuine v1 document — the pre-M3 schema had no `meta` and used
    // schema_version 1. Its checksum is computed over {schema_version, hash,
    // state}. With a matched balance_hash it reaches the migration chain (a
    // real economy change would trip balance_hash first — pre-release we have
    // no v1 save to rescue; this proves the mechanism works).
    final b = _balance();
    final s = GameState.initial(b, 7);
    Engine(b).tick(s, [OrderMaterial(0, 1)]);
    final v1 = _sealed({
      'schema_version': 1,
      'balance_hash': b.contentHash,
      'state': s.toJson(),
    });

    final restored = decodeSave(v1, b);
    // State survives the migration untouched…
    expect(restored.state.stateHash(), s.stateHash());
    // …and a default meta is injected.
    expect(restored.meta.soulPoints, 0);
    expect(restored.meta.tutorialDone, isFalse);
    expect(restored.meta.unlockLevels, isEmpty);
  });

  test('migration chain is registered for AC-15', () {
    expect(saveSchemaVersion, 2);
    expect(saveMigrations.containsKey(1), isTrue);
  });
}
