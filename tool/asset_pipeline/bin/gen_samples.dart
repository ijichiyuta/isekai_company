import 'dart:io';

import 'package:image/image.dart' as img;

/// Generates a few palette-conformant 32×32 placeholder icons so the pipeline +
/// audit + CI can be proven end-to-end WITHOUT AI image generation (which this
/// environment can't do). Real art replaces these via quantize.dart later.
/// Colours are drawn straight from assets/palette.json values (art-bible §3),
/// left-top light, selective dark-brown outline.
///
/// Usage: dart run bin/gen_samples.dart <outDir>
void main(List<String> args) {
  final outDir = args.isNotEmpty ? args[0] : 'assets/generated';
  Directory(outDir).createSync(recursive: true);

  _write('$outDir/coin.png', _disc(
    outline: 0x2A1E14,
    base: _c(0xE0AE2E),
    hi: _c(0xF2D06B),
    lo: _c(0x9A6E12),
  ));
  _write('$outDir/herb.png', _disc(
    outline: 0x2E4F1B,
    base: _c(0x6BA83E),
    hi: _c(0x9FCB6B),
    lo: _c(0x4A7A2A),
  ));
  _write('$outDir/vial.png', _disc(
    outline: 0x1D4763,
    base: _c(0x4A97BE),
    hi: _c(0x7FC3D6),
    lo: _c(0x2E6A8E),
  ));
  stdout.writeln('generated 3 palette-conformant sample icons in $outDir');
}

/// Pack an RGB hex into an image ColorRgba8 (opaque).
img.ColorRgb8 _c(int rgb) =>
    img.ColorRgb8((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);

/// A shaded disc: base fill, highlight toward top-left, shade bottom-right,
/// 1px selective outline. All colours are palette entries.
img.Image _disc({
  required int outline,
  required img.Color base,
  required img.Color hi,
  required img.Color lo,
}) {
  const n = 32;
  final im = img.Image(width: n, height: n, numChannels: 4);
  img.fill(im, color: img.ColorRgba8(0, 0, 0, 0)); // transparent
  const cx = 15.5, cy = 15.5, r = 13.0;
  final outlineC = _c(outline);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final dx = x - cx, dy = y - cy;
      final d = dx * dx + dy * dy;
      if (d > r * r) continue;
      if (d > (r - 1.2) * (r - 1.2)) {
        im.setPixelRgba(x, y, outlineC.r, outlineC.g, outlineC.b, 255);
        continue;
      }
      // top-left highlight, bottom-right shade
      final img.Color c = (dx + dy < -5) ? hi : (dx + dy > 5 ? lo : base);
      im.setPixelRgba(x, y, c.r, c.g, c.b, 255);
    }
  }
  return im;
}

void _write(String path, img.Image im) {
  File(path).writeAsBytesSync(img.encodePng(im));
}
