import 'dart:convert';
import 'dart:io';

/// The fixed art palette (art-bible.md §3). Loads assets/palette.json and
/// snaps arbitrary RGB to the nearest palette entry.
class Palette {
  final List<(int r, int g, int b)> colors;
  Palette(this.colors);

  factory Palette.load(String path) {
    final json = jsonDecode(File(path).readAsStringSync())
        as Map<String, dynamic>;
    final colors = <(int, int, int)>[];
    for (final hex in (json['colors'] as List).cast<String>()) {
      colors.add(_hex(hex));
    }
    if (colors.isEmpty) throw StateError('palette has no colors');
    return Palette(colors);
  }

  static (int, int, int) _hex(String hex) {
    final h = hex.replaceFirst('#', '');
    return (
      int.parse(h.substring(0, 2), radix: 16),
      int.parse(h.substring(2, 4), radix: 16),
      int.parse(h.substring(4, 6), radix: 16),
    );
  }

  /// Nearest palette colour by squared Euclidean distance in RGB.
  (int, int, int) nearest(int r, int g, int b) {
    var best = colors.first;
    var bestD = 1 << 30;
    for (final c in colors) {
      final dr = c.$1 - r, dg = c.$2 - g, db = c.$3 - b;
      final d = dr * dr + dg * dg + db * db;
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }

  bool contains(int r, int g, int b) {
    for (final c in colors) {
      if (c.$1 == r && c.$2 == g && c.$3 == b) return true;
    }
    return false;
  }
}
