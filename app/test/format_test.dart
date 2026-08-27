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

  test('calendar maps absolute weeks to year/season/week', () {
    expect(calendar(0), (year: 1, season: 0, weekOfSeason: 1));
    expect(calendar(11), (year: 1, season: 0, weekOfSeason: 12));
    expect(calendar(12), (year: 1, season: 1, weekOfSeason: 1));
    expect(calendar(47), (year: 1, season: 3, weekOfSeason: 12));
    expect(calendar(48), (year: 2, season: 0, weekOfSeason: 1));
    expect(seasonNames[calendar(12).season], '夏');
  });
}
