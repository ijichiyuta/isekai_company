import 'package:flutter/material.dart';

/// A hand-authored pixel-art sprite (カイロ系「ドット絵」). [rows] are equal-length
/// strings; each character is a key into [palette]. `.` and ` ` are transparent.
/// Rendered crisply (no anti-aliasing, integer pixel size) — the whole art
/// style lives in code, with NO bundled image assets (要件§8.2の内製方針)。
@immutable
class PixelSprite {
  final List<String> rows;
  final Map<String, Color> palette;
  const PixelSprite(this.rows, this.palette);

  int get width => rows.isEmpty ? 0 : rows.first.length;
  int get height => rows.length;

  /// True when every row is [width] wide — the invariant the renderer needs.
  /// Checked by test/pixel_sprites_test.dart so an authoring typo fails fast.
  bool get isRectangular => rows.every((r) => r.length == width);
}

/// Paints a [PixelSprite] as filled, axis-aligned squares — no AA so edges stay
/// razor-sharp at any [px] (the dot-e look). A half-pixel overdraw closes the
/// hairline seams that rounding can otherwise leave between cells.
class _PixelPainter extends CustomPainter {
  const _PixelPainter(this.sprite, this.px);
  final PixelSprite sprite;
  final double px;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..isAntiAlias = false
      ..style = PaintingStyle.fill;
    for (var y = 0; y < sprite.rows.length; y++) {
      final row = sprite.rows[y];
      for (var x = 0; x < row.length; x++) {
        final ch = row[x];
        if (ch == '.' || ch == ' ') continue;
        final c = sprite.palette[ch];
        if (c == null) continue;
        paint.color = c;
        canvas.drawRect(
          Rect.fromLTWH(x * px, y * px, px + 0.5, px + 0.5),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) => old.sprite != sprite || old.px != px;
}

/// Renders a [PixelSprite]. Give it a fixed [pixelSize] (each sprite pixel = N
/// logical px) OR a target [height] (the pixel size is floored so it stays an
/// integer → crisp). Optionally [flip]ped horizontally (facing) and given a
/// [semanticLabel] for a11y (replaces the emoji's implicit text).
class PixelView extends StatelessWidget {
  const PixelView(
    this.sprite, {
    super.key,
    this.pixelSize,
    this.height,
    this.flip = false,
    this.semanticLabel,
  }) : assert(pixelSize != null || height != null, 'give pixelSize or height');

  final PixelSprite sprite;
  final double? pixelSize;
  final double? height;
  final bool flip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    var px = pixelSize ?? (height! / sprite.height).floorToDouble();
    if (px < 1) px = 1;
    Widget child = SizedBox(
      width: sprite.width * px,
      height: sprite.height * px,
      child: CustomPaint(painter: _PixelPainter(sprite, px)),
    );
    if (flip) {
      child = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: child,
      );
    }
    if (semanticLabel != null) {
      child = Semantics(label: semanticLabel, image: true, child: child);
    }
    return child;
  }
}

/// An AppBar title with a leading pixel icon — ties the management screens into
/// the same iconography as the main HUD / nav.
class PixelTitle extends StatelessWidget {
  const PixelTitle(this.sprite, this.text, {super.key});
  final PixelSprite sprite;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PixelView(sprite, height: 20),
      const SizedBox(width: 8),
      Text(text),
    ],
  );
}
