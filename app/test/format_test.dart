import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/format.dart';

void main() {
  test('formatG uses K/M/B/T with ~3 significant digits', () {
    expect(formatG(0), '0');
    expect(formatG(999), '999');
    expect(formatG(1000), '1K');
    expect(formatG(1500), '1.5K');
    expect(formatG(12345), '12.3K');
    expect(formatG(999999), '999K');
    expect(formatG(1000000), '1M');
    expect(formatG(15000000), '15M');
    expect(formatG(300000000), '300M');
    expect(formatG(1500000000), '1.5B');
    expect(formatG(2000000000000), '2T');
    expect(formatG(-2000), '-2K');
  });

  test('categoryJa localizes known keys and passes unknowns through', () {
    expect(categoryJa('food'), '食品');
    expect(categoryJa('tool'), '道具');
    expect(categoryJa('clothing'), '衣類');
    expect(categoryJa('medicine'), '薬');
    expect(categoryJa('luxury'), '嗜好品');
    // Never blank: an unmapped id is shown verbatim rather than dropped.
    expect(categoryJa('mystery'), 'mystery');
    expect(categoryJa(''), '');
  });

  test('gold spells the ゴールド unit and keeps K/M magnitude', () {
    expect(gold(0), '0ゴールド');
    expect(gold(2), '2ゴールド');
    expect(gold(850), '850ゴールド');
    expect(gold(128000), '128Kゴールド');
    expect(gold(49000000), '49Mゴールド');
  });

  test('methodJa localizes every bundled craft method (no English leaks)', () {
    expect(methodJa('cooling'), '冷却');
    expect(methodJa('heating'), '加熱');
    expect(methodJa('fermentation'), '発酵');
    expect(methodJa('drying'), '乾燥');
    expect(methodJa('grinding'), '粉砕');
    expect(methodJa('precision'), '精密');
    expect(methodJa('sewing'), '裁縫');
    expect(methodJa('compounding'), '調合');
    // Unknown ids pass through rather than vanish.
    expect(methodJa('alchemy'), 'alchemy');
  });

  test('calendar maps absolute weeks to year/season/week', () {
    expect(calendar(0), (year: 1, season: 0, weekOfSeason: 1));
    expect(calendar(11), (year: 1, season: 0, weekOfSeason: 12));
    expect(calendar(12), (year: 1, season: 1, weekOfSeason: 1));
    expect(calendar(47), (year: 1, season: 3, weekOfSeason: 12));
    expect(calendar(48), (year: 2, season: 0, weekOfSeason: 1));
    expect(seasonNames[calendar(12).season], '夏');
  });
}
