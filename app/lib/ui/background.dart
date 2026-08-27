import 'package:flutter/material.dart';

/// Ambient, NON-pixel background for screens (the user asked for richer
/// scenery; wallpapers don't need to be dot-art). A warm vertical gradient with
/// a couple of soft radial glows so screens feel lit, not flat. Different
/// [mood]s tint it for context (shop interior, sky, royal, dusk).
enum BgMood { interior, sky, royal, dusk }

class AppBackground extends StatelessWidget {
  const AppBackground({
    super.key,
    required this.child,
    this.mood = BgMood.interior,
  });
  final Widget child;
  final BgMood mood;

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

  @override
  Widget build(BuildContext context) {
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
