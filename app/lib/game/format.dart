/// Number formatting for the HUD (requirements §10.5: K/M/B/T, 3 sig figs).
/// Integer math only — mirrors the core's no-floating-point discipline.
library;

String formatG(int g) {
  final neg = g < 0;
  final v = neg ? -g : g;
  final String out;
  if (v < 1000) {
    out = '$v';
  } else if (v < 1000000) {
    out = _sig(v, 1000, 'K');
  } else if (v < 1000000000) {
    out = _sig(v, 1000000, 'M');
  } else if (v < 1000000000000) {
    out = _sig(v, 1000000000, 'B');
  } else {
    out = _sig(v, 1000000000000, 'T');
  }
  return neg ? '-$out' : out;
}

/// value/divisor with up to 3 significant digits, truncated, integer math.
String _sig(int value, int divisor, String suffix) {
  final whole = value ~/ divisor;
  final remainder = value - whole * divisor;
  if (whole >= 100) return '$whole$suffix';
  if (whole >= 10) {
    final d1 = (remainder * 10) ~/ divisor;
    return d1 == 0 ? '$whole$suffix' : '$whole.$d1$suffix';
  }
  final d2 = (remainder * 100) ~/ divisor;
  if (d2 == 0) return '$whole$suffix';
  var frac = d2.toString().padLeft(2, '0');
  if (frac.endsWith('0')) frac = frac.substring(0, 1); // 50 → 5, 10 → 1
  return '$whole.$frac$suffix';
}

/// Year/season/week from an absolute week index (48 weeks/year, 12/season).
({int year, int season, int weekOfSeason}) calendar(int week) {
  final year = week ~/ 48 + 1;
  final within = week % 48;
  final season = within ~/ 12; // 0..3
  final weekOfSeason = within % 12 + 1;
  return (year: year, season: season, weekOfSeason: weekOfSeason);
}

const seasonNames = ['春', '夏', '秋', '冬'];

/// Market category ids are English (the sim's logic keys); the player sees them
/// in Japanese. Unknown keys pass through unchanged so nothing is ever blank.
const _categoryJa = {
  'food': '食品',
  'tool': '道具',
  'clothing': '衣類',
  'medicine': '薬',
  'luxury': '嗜好品',
};

String categoryJa(String category) => _categoryJa[category] ?? category;

/// Craft-method ids are English logic keys (recipes.json / determinism); the
/// player sees them in Japanese. Unknown keys pass through unchanged.
const _methodJa = {
  'cooling': '冷却',
  'heating': '加熱',
  'fermentation': '発酵',
  'drying': '乾燥',
  'grinding': '粉砕',
  'precision': '精密',
  'sewing': '裁縫',
  'compounding': '調合',
};

String methodJa(String method) => _methodJa[method] ?? method;
