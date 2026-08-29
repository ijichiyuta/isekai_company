import 'package:flutter/material.dart';

/// Ambient, NON-pixel background for screens (the user asked for richer
/// scenery; wallpapers don't need to be dot-art). A warm vertical gradient with
/// a couple of soft radial glows so screens feel lit, not flat. Different
/// [mood]s tint it for context (shop interior, sky, royal, dusk).
///
/// With [scenery] on it adds depth the Kairosoft way — a distant fantasy-town
/// rooftop silhouette in two parallax bands plus faint sky motes — so the space
/// around the diorama reads as a lived-in world, not a flat panel.
enum BgMood { interior, sky, royal, dusk }

class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.mood = BgMood.interior,
    this.scenery = false,
    this.season = -1, // 0春/1夏/2秋/3冬, -1 = none (tints the brick + motes)
  });
  final Widget child;
  final BgMood mood;
  final bool scenery;
  final int season;

  List<Color> get _stops => switch (mood) {
    BgMood.interior => const [
      Color(0xFFFBF3DE),
      Color(0xFFF3E6C4),
      Color(0xFFE9D6A8),
    ],
    BgMood.sky => const [
      Color(0xFFBFE3F2),
      Color(0xFFDDF0F7),
      Color(0xFFF3ECD6),
    ],
    BgMood.royal => const [
      Color(0xFFEDE6F5),
      Color(0xFFE7DCEF),
      Color(0xFFD9C9E2),
    ],
    BgMood.dusk => const [
      Color(0xFF3A3350),
      Color(0xFF5A4A63),
      Color(0xFF9A7B72),
    ],
  };

  Color get _glowWarm => switch (mood) {
    BgMood.dusk => const Color(0x33FFC98A),
    BgMood.royal => const Color(0x33FFF0C0),
    _ => const Color(0x3AFFE9B0),
  };

  // Silhouette + mote tints per mood (kept low-alpha so the diorama stays the
  // star and text over the background stays legible).
  (Color, Color, Color) get _sceneryTones => switch (mood) {
    BgMood.interior => const (
      Color(0x3C7C5636),
      Color(0x63513418),
      Color(0x88E7B24A),
    ),
    BgMood.sky => const (
      Color(0x223C6E9E),
      Color(0x304E6889),
      Color(0x59FFFFFF),
    ),
    BgMood.royal => const (
      Color(0x226E5A86),
      Color(0x3051406B),
      Color(0x55FFF0C0),
    ),
    BgMood.dusk => const (
      Color(0x332A2440),
      Color(0x5514112A),
      Color(0x66FFD98A),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (far, near, mote) = _sceneryTones;
    // The indoor shop reads best as a warm brick wall (the user's suggestion);
    // outdoor moods get a distant town skyline. Both fill the space around the
    // diorama so it never looks like a flat panel.
    final CustomPainter? painter = !scenery
        ? null
        : mood == BgMood.interior
        ? _BrickPainter(season: season)
        : _SceneryPainter(far: far, near: near, mote: mote);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _stops,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -90, right: -50, child: _glow(240, _glowWarm)),
          Positioned(
            bottom: -70,
            left: -60,
            child: _glow(220, const Color(0x1EFFFFFF)),
          ),
          if (painter != null)
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: painter)),
            ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }

  static Widget _glow(double d, Color c) => IgnorePointer(
    child: Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [c, c.withAlpha(0)]),
      ),
    ),
  );
}

/// A brick wall for the indoor shop surround. Per-brick tone varies from a
/// fixed hash (deterministic → golden-stable), with a lit top edge + shadowed
/// mortar. The palette shifts with the [season] and a few motes drift down
/// (petals / leaves / snow) so the world feels seasonal, not static.
class _BrickPainter extends CustomPainter {
  const _BrickPainter({required this.season});
  final int season;

  static const _bw = 46.0;
  static const _bh = 20.0;
  static const _mortar = 2.5;
  static const _topEdge = Color(0x33FFFFFF);
  static const _botEdge = Color(0x1A5A3A1E);

  // (light brick, dark brick, mortar) per season; default = warm sandstone.
  (Color, Color, Color) get _tones => switch (season) {
    0 => const (Color(0xFFE7CFA6), Color(0xFFCBAD82), Color(0xFFBFA982)), // 春
    2 => const (Color(0xFFDCAB74), Color(0xFFBC8850), Color(0xFFAE8A62)), // 秋
    3 => const (Color(0xFFD3CCC0), Color(0xFFB0A594), Color(0xFFAEA48F)), // 冬
    _ => const (Color(0xFFE0C295), Color(0xFFC69A67), Color(0xFFBBA47C)), // 夏/既定
  };

  // (mote colour, kind) — 0:petal 1:leaf 2:snow 3:none.
  (Color, int) get _mote => switch (season) {
    0 => const (Color(0x66F5C4D2), 0), // 春 花びら
    2 => const (Color(0x66C9772F), 1), // 秋 落ち葉
    3 => const (Color(0x88FFFFFF), 2), // 冬 雪
    _ => const (Color(0x00000000), 3), // 夏 なし
  };

  @override
  void paint(Canvas canvas, Size size) {
    final (light, dark, mortarColor) = _tones;
    canvas.drawRect(Offset.zero & size, Paint()..color = mortarColor);
    final brick = Paint();
    final top = Paint()..color = _topEdge;
    final bot = Paint()..color = _botEdge;
    var row = 0;
    for (var y = -_bh; y < size.height + _bh; y += _bh) {
      final rowOffset = row.isEven ? 0.0 : -_bw / 2;
      var col = 0;
      for (var x = rowOffset - _bw; x < size.width + _bw; x += _bw) {
        final h = ((row * 73856093) ^ (col * 19349663)) & 0x7fffffff;
        final t = (h % 1000) / 1000.0;
        brick.color = Color.lerp(light, dark, t)!;
        final r = Rect.fromLTWH(
          x + _mortar,
          y + _mortar,
          _bw - _mortar * 2,
          _bh - _mortar * 2,
        );
        canvas.drawRect(r, brick);
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 1.5), top);
        canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 1.5, r.width, 1.5), bot);
        col++;
      }
      row++;
    }
    _drawMotes(canvas, size);
  }

  void _drawMotes(Canvas canvas, Size size) {
    final (color, kind) = _mote;
    if (kind == 3) return;
    final p = Paint()..color = color;
    var s = 137;
    double rnd() {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      return s / 0x7fffffff;
    }

    for (var i = 0; i < 22; i++) {
      final x = rnd() * size.width;
      final y = rnd() * size.height;
      final r = 2.0 + rnd() * 2.0;
      if (kind == 2) {
        canvas.drawCircle(Offset(x, y), r * 0.8, p); // snow
      } else if (kind == 0) {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r), p); // petal
      } else {
        // leaf — a small tilted rounded rect
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rnd() * 3.14);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: r * 2.4, height: r * 1.3),
            Radius.circular(r),
          ),
          p,
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_BrickPainter old) => old.season != season;
}

/// Draws the distant town skyline + sky motes. Everything is derived from fixed
/// seeds (a tiny LCG), so the layout is deterministic and golden-stable — no
/// wall-clock or RNG at build time.
class _SceneryPainter extends CustomPainter {
  _SceneryPainter({required this.far, required this.near, required this.mote});
  final Color far;
  final Color near;
  final Color mote;

  @override
  void paint(Canvas canvas, Size size) {
    // Far band (smaller, higher, fainter) then near band (taller, in front).
    _skyline(canvas, size, far, baseFrac: 0.74, unit: 30, minH: 22, maxH: 66, seed: 7);
    _skyline(canvas, size, near, baseFrac: 0.88, unit: 42, minH: 38, maxH: 104, seed: 23);
    _motes(canvas, size);
  }

  void _skyline(
    Canvas canvas,
    Size size,
    Color color, {
    required double baseFrac,
    required double unit,
    required double minH,
    required double maxH,
    required int seed,
  }) {
    final paint = Paint()..color = color;
    final baseY = size.height * baseFrac;
    var s = seed;
    double rnd() {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      return s / 0x7fffffff;
    }

    for (var x = -unit; x < size.width + unit; x += unit) {
      final w = unit * (0.66 + rnd() * 0.5);
      final h = minH + rnd() * (maxH - minH);
      final top = baseY - h;
      final left = x, right = x + w, mid = x + w / 2;
      final roll = rnd();
      final path = Path();
      if (roll < 0.6) {
        // peaked-roof house
        path.moveTo(left, top + w * 0.42);
        path.lineTo(mid, top - w * 0.14);
        path.lineTo(right, top + w * 0.42);
        path.lineTo(right, size.height);
        path.lineTo(left, size.height);
        path.close();
      } else if (roll < 0.84) {
        // flat tower / block
        path.addRect(Rect.fromLTWH(left, top, w, size.height - top));
      } else {
        // spired tower
        path.moveTo(mid, top - w * 0.5);
        path.lineTo(right, top + w * 0.22);
        path.lineTo(right, size.height);
        path.lineTo(left, size.height);
        path.lineTo(left, top + w * 0.22);
        path.close();
      }
      canvas.drawPath(path, paint);
    }
  }

  void _motes(Canvas canvas, Size size) {
    final paint = Paint()..color = mote;
    var s = 101;
    double rnd() {
      s = (s * 1103515245 + 12345) & 0x7fffffff;
      return s / 0x7fffffff;
    }

    for (var i = 0; i < 26; i++) {
      final x = rnd() * size.width;
      final y = rnd() * size.height * 0.6;
      final r = 1.0 + rnd() * 1.6;
      if (rnd() < 0.5) {
        canvas.drawCircle(Offset(x, y), r, paint);
      } else {
        // a small 4-point twinkle
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: r * 2.8, height: 0.9),
          paint,
        );
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: 0.9, height: r * 2.8),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SceneryPainter old) =>
      old.far != far || old.near != near || old.mote != mote;
}
