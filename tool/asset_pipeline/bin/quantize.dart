import 'dart:io';

import 'package:image/image.dart' as img;

import '../lib/palette.dart';

/// Snaps an image to the fixed palette and normalizes size with nearest-
/// neighbour (art-bible.md §2/§7). This is the safety net that collapses AI
/// palette drift onto the canonical colours.
///
/// Usage: dart run bin/quantize.dart <in.png> <out.png> [size] [palette.json]
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: quantize <in.png> <out.png> [size=32] [palette]');
    exit(2);
  }
  final size = args.length >= 3 ? int.parse(args[2]) : 32;
  final palettePath = args.length >= 4 ? args[3] : 'assets/palette.json';
  final palette = Palette.load(_resolve(palettePath));

  final src = img.decodePng(File(args[0]).readAsBytesSync());
  if (src == null) {
    stderr.writeln('could not decode ${args[0]}');
    exit(1);
  }
  final resized = img.copyResize(src,
      width: size, height: size, interpolation: img.Interpolation.nearest);

  for (var y = 0; y < resized.height; y++) {
    for (var x = 0; x < resized.width; x++) {
      final p = resized.getPixel(x, y);
      final a = p.a.toInt();
      if (a < 128) {
        resized.setPixelRgba(x, y, 0, 0, 0, 0); // fully transparent
        continue;
      }
      final (r, g, b) =
          palette.nearest(p.r.toInt(), p.g.toInt(), p.b.toInt());
      resized.setPixelRgba(x, y, r, g, b, 255);
    }
  }

  File(args[1]).writeAsBytesSync(img.encodePng(resized));
  stdout.writeln('quantized ${args[0]} -> ${args[1]} (${size}x$size)');
}

String _resolve(String p) {
  if (File(p).existsSync()) return p;
  final up = '../../$p';
  if (File(up).existsSync()) return up;
  return p;
}
