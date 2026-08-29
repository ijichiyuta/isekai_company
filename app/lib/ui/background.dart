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
  });
  final Widget child;
  final BgMood mood;
  final bool scenery;

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
        ? _BrickPainter()
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

/// A warm sandstone brick wall for the indoor shop surround. Per-brick tone
/// varies from a fixed hash (deterministic → golden-stable), with a lit top
/// edge and a shadowed mortar so the wall has depth, not a flat repeat.
class _BrickPainter extends CustomPainter {
  static const _bw = 46.0; // brick width
  static const _bh = 20.0; // brick height
  static const _mortar = 2.5;
  static const _light = Color(0xFFE0C295); // brick highlight tone
  static const _dark = Color(0xFFC69A67); // brick shadow tone
  static const _mortarColor = Color(0xFFBBA47C);
  static const _topEdge = Color(0x33FFFFFF);
  static const _botEdge = Color(0x1A5A3A1E);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _mortarColor);
    final brick = Paint();
    final top = Paint()..color = _topEdge;
    final bot = Paint()..color = _botEdge;
    var row = 0;
    for (var y = -_bh; y < size.height + _bh; y += _bh) {
      final rowOffset = row.isEven ? 0.0 : -_bw / 2;
      var col = 0;
      for (var x = rowOffset - _bw; x < size.width + _bw; x += _bw) {
        // deterministic 0..1 from the brick's grid position
        final h = ((row * 73856093) ^ (col * 19349663)) & 0x7fffffff;
        final t = (h % 1000) / 1000.0;
        brick.color = Color.lerp(_light, _dark, t)!;
        final r = Rect.fromLTWH(
          x + _mortar,
          y + _mortar,
          _bw - _mortar * 2,
          _bh - _mortar * 2,
        );
        canvas.drawRect(r, brick);
        // lit top, shadowed bottom for a shallow bevel
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 1.5), top);
        canvas.drawRect(
          Rect.fromLTWH(r.left, r.bottom - 1.5, r.width, 1.5),
          bot,
        );
        col++;
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(_BrickPainter old) => false;
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
