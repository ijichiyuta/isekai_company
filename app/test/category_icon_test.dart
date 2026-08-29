import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/format.dart';
import 'package:isekai_app/ui/pixel/sprites.dart' as art;

import 'helpers.dart';

// Guards the balance → UI icon binding: a recipe whose `category` is misspelt
// (or missing from the market) would silently fall back to the material "sack"
// icon in the develop/produce/sell lists. This catches that against the real
// bundled recipes, not just a golden diff.

void main() {
  const knownCategories = {'food', 'tool', 'clothing', 'medicine', 'luxury'};

  test('every bundled recipe maps to a real category icon (not the fallback)', () {
    final b = loadTestBalanceMarket();
    expect(b.recipes, isNotEmpty);
    for (final r in b.recipes) {
      expect(
        knownCategories.contains(r.category),
        isTrue,
        reason: 'recipe "${r.name}" has unknown category "${r.category}"',
      );
      expect(
        identical(art.categoryIcon(r.category), art.sack),
        isFalse,
        reason: 'recipe "${r.name}" falls back to the material sack icon',
      );
    }
  });

  test('categoryIcon returns a distinct icon per category + a sack fallback', () {
    final icons = {
      for (final cat in knownCategories) art.categoryIcon(cat),
    };
    expect(icons.length, knownCategories.length); // all five distinct
    expect(identical(art.categoryIcon('unknown'), art.sack), isTrue);
    expect(identical(art.categoryIcon(''), art.sack), isTrue);
  });

  test('every material maps to its own distinct icon (not the shared sack)', () {
    final b = loadTestBalanceMarket();
    expect(b.materials, isNotEmpty);
    // Each bundled material id resolves to a real, non-fallback icon.
    for (final m in b.materials) {
      expect(
        identical(art.materialIcon(m.id), art.sack),
        isFalse,
        reason: 'material "${m.name}" (id ${m.id}) falls back to the sack icon',
      );
    }
    // All icons are distinct — no two materials share a sprite.
    final icons = {for (final m in b.materials) art.materialIcon(m.id)};
    expect(icons.length, b.materials.length);
    // Out-of-range ids fall back to the generic sack (defensive).
    expect(identical(art.materialIcon(-1), art.sack), isTrue);
    expect(identical(art.materialIcon(9999), art.sack), isTrue);
  });

  test('every bundled craft method is localized to Japanese (no English UI)', () {
    final b = loadTestBalanceMarket();
    expect(b.methods, isNotEmpty);
    for (final m in b.methods) {
      // A mapped method returns a different (Japanese) string; an unmapped one
      // would leak its raw English key into the develop screen.
      expect(
        methodJa(m),
        isNot(m),
        reason: 'method "$m" has no Japanese label in methodJa()',
      );
    }
  });
}
