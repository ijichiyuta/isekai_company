import 'dart:math' as math;
import 'dart:ui' show Color;

import 'pixel_art.dart';

/// A mutable pixel grid for composing HIGH-RESOLUTION, shaded sprites in code
/// (loops for texture, tonal ramps for shading, dithered gradients, selective
/// outlining) — the difference between "programmer art" and hand-crafted dot-e.
/// `.` is transparent. Convert to a [PixelSprite] with [toSprite].
class PixelCanvas {
  final int width;
  final int height;
  final List<List<String>> _px;

  PixelCanvas(this.width, this.height)
    : _px = List.generate(height, (_) => List<String>.filled(width, '.'));

  bool _inside(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  void set(int x, int y, String c) {
    if (_inside(x, y)) _px[y][x] = c;
  }

  String at(int x, int y) => _inside(x, y) ? _px[y][x] : '.';

  void rect(int x, int y, int w, int h, String c) {
    for (var j = y; j < y + h; j++) {
      for (var i = x; i < x + w; i++) {
        set(i, j, c);
      }
    }
  }

  void hline(int x, int y, int w, String c) {
    for (var i = x; i < x + w; i++) {
      set(i, y, c);
    }
  }

  void vline(int x, int y, int h, String c) {
    for (var j = y; j < y + h; j++) {
      set(x, j, c);
    }
  }

  void border(int x, int y, int w, int h, String c) {
    hline(x, y, w, c);
    hline(x, y + h - 1, w, c);
    vline(x, y, h, c);
    vline(x + w - 1, y, h, c);
  }

  /// Vertical gradient: [tones] applied top→bottom across [h] rows.
  void rampV(int x, int y, int w, int h, List<String> tones) {
    for (var j = 0; j < h; j++) {
      final t = tones[(j * tones.length ~/ h).clamp(0, tones.length - 1)];
      hline(x, y + j, w, t);
    }
  }

  /// Horizontal gradient: [tones] applied left→right across [w] columns.
  void rampH(int x, int y, int w, int h, List<String> tones) {
    for (var i = 0; i < w; i++) {
      final t = tones[(i * tones.length ~/ w).clamp(0, tones.length - 1)];
      vline(x + i, y, h, t);
    }
  }

  /// 2-tone checkerboard fill — smooths a gradient step (classic pixel dither).
  void dither(int x, int y, int w, int h, String c1, String c2) {
    for (var j = 0; j < h; j++) {
      for (var i = 0; i < w; i++) {
        set(x + i, y + j, ((i + j) & 1) == 0 ? c1 : c2);
      }
    }
  }

  void disc(int cx, int cy, int r, String c) {
    for (var j = -r; j <= r; j++) {
      for (var i = -r; i <= r; i++) {
        if (i * i + j * j <= r * r) set(cx + i, cy + j, c);
      }
    }
  }

  /// A sphere-shaded disc: [tones] light→dark, lit from the top-left.
  void discShaded(int cx, int cy, int r, List<String> tones) {
    final n = tones.length;
    for (var j = -r; j <= r; j++) {
      for (var i = -r; i <= r; i++) {
        if (i * i + j * j > r * r) continue;
        // distance from the top-left highlight, normalised 0..1
        final d = ((i + r) + (j + r)) / (4 * r);
        final idx = (d * (n - 1)).round().clamp(0, n - 1);
        set(cx + i, cy + j, tones[idx]);
      }
    }
  }

  void ellipse(int cx, int cy, int rx, int ry, String c) {
    for (var j = -ry; j <= ry; j++) {
      for (var i = -rx; i <= rx; i++) {
        if (i * i * ry * ry + j * j * rx * rx <= rx * rx * ry * ry) {
          set(cx + i, cy + j, c);
        }
      }
    }
  }

  void line(int x0, int y0, int x1, int y1, String c) {
    var dx = (x1 - x0).abs(), dy = -(y1 - y0).abs();
    var sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    var err = dx + dy, x = x0, y = y0;
    while (true) {
      set(x, y, c);
      if (x == x1 && y == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y += sy;
      }
    }
  }

  /// Fill a regular [points]-pointed star (outer radius [rO], inner [rI]),
  /// shaded top→bottom by [tones] (light→dark).
  void starFill(
    double cx,
    double cy,
    double rO,
    double rI,
    int points,
    List<String> tones,
  ) {
    final verts = <List<double>>[];
    for (var i = 0; i < points * 2; i++) {
      final a = -math.pi / 2 + i * math.pi / points;
      final r = i.isEven ? rO : rI;
      verts.add([cx + r * math.cos(a), cy + r * math.sin(a)]);
    }
    final top = cy - rO, bot = cy + rO;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!_inPoly(x + 0.5, y + 0.5, verts)) continue;
        final f = ((y - top) / (bot - top)).clamp(0.0, 1.0);
        final idx = (f * (tones.length - 1)).round().clamp(0, tones.length - 1);
        set(x, y, tones[idx]);
      }
    }
  }

  static bool _inPoly(double px, double py, List<List<double>> v) {
    var inside = false;
    for (var i = 0, j = v.length - 1; i < v.length; j = i++) {
      final xi = v[i][0], yi = v[i][1], xj = v[j][0], yj = v[j][1];
      if (((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Fill only where currently transparent (paint "behind" existing pixels).
  void fillBehind(int x, int y, int w, int h, String c) {
    for (var j = y; j < y + h; j++) {
      for (var i = x; i < x + w; i++) {
        if (at(i, j) == '.') set(i, j, c);
      }
    }
  }

  /// Add a 1px [c] outline around the silhouette (8-connected) on transparent
  /// cells — computed on a snapshot so it never thickens itself.
  void outline(String c) {
    final adds = <int>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_px[y][x] != '.') continue;
        var touch = false;
        for (var dy = -1; dy <= 1 && !touch; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final n = at(x + dx, y + dy);
            if (n != '.' && n != c) {
              touch = true;
              break;
            }
          }
        }
        if (touch) adds.add(y * width + x);
      }
    }
    for (final p in adds) {
      _px[p ~/ width][p % width] = c;
    }
  }

  /// Selective outlining: recolor outline pixels [outlineKey] on the lit
  /// (top / left) edge of the silhouette to a lighter [litKey] — the "selout"
  /// technique that stops the outline reading as a flat black sticker.
  void selout(String outlineKey, String litKey) {
    final adds = <int>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_px[y][x] != outlineKey) continue;
        if (at(x, y - 1) == '.' || at(x - 1, y) == '.') {
          adds.add(y * width + x);
        }
      }
    }
    for (final p in adds) {
      _px[p ~/ width][p % width] = litKey;
    }
  }

  /// A soft elliptical ground shadow (only where transparent).
  void shadow(int cx, int cy, int rx, int ry, String c) {
    for (var j = -ry; j <= ry; j++) {
      for (var i = -rx; i <= rx; i++) {
        if (i * i * ry * ry + j * j * rx * rx > rx * rx * ry * ry) continue;
        if (at(cx + i, cy + j) == '.') set(cx + i, cy + j, c);
      }
    }
  }

  PixelSprite toSprite(Map<String, Color> palette) =>
      PixelSprite([for (final row in _px) row.join()], palette);
}
