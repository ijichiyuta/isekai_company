import 'package:flutter_test/flutter_test.dart';
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
}
