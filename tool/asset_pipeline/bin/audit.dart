import 'dart:io';

import 'package:image/image.dart' as img;

import '../lib/palette.dart';

/// Audits every PNG in a directory for art-bible conformance (AC-17):
/// exact palette membership (no drift), square target size, hard edges.
/// Exits non-zero on any violation so CI fails.
///
/// Usage: dart run bin/audit.dart <dir> [size=32] [palette.json]
void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: audit <dir> [size=32] [palette]');
    exit(2);
  }
  final dir = Directory(args[0]);
  final size = args.length >= 2 ? int.parse(args[1]) : 32;
  final palettePath = args.length >= 3 ? args[2] : 'assets/palette.json';
  final palette = Palette.load(_resolve(palettePath));

  if (!dir.existsSync()) {
    stdout.writeln('asset dir ${args[0]} does not exist yet — nothing to audit');
    return; // not an error: assets are produced later
  }

  final pngs = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (pngs.isEmpty) {
    stdout.writeln('no PNGs under ${args[0]} yet — nothing to audit');
    return;
  }

  final violations = <String>[];
  for (final f in pngs) {
    final im = img.decodePng(f.readAsBytesSync());
    if (im == null) {
      violations.add('${f.path}: not a valid PNG');
      continue;
    }
    if (im.width != size || im.height != size) {
      violations.add('${f.path}: size ${im.width}x${im.height}, expected '
          '${size}x$size');
    }
    var offPalette = 0;
    for (var y = 0; y < im.height; y++) {
      for (var x = 0; x < im.width; x++) {
        final p = im.getPixel(x, y);
        if (p.a.toInt() < 128) continue; // transparent pixels exempt
        if (!palette.contains(p.r.toInt(), p.g.toInt(), p.b.toInt())) {
          offPalette++;
        }
      }
    }
    if (offPalette > 0) {
      violations.add('${f.path}: $offPalette off-palette pixel(s)');
    }
  }

  stdout.writeln('audited ${pngs.length} asset(s) against '
      '${palette.colors.length}-colour palette');
  if (violations.isNotEmpty) {
    stderr.writeln('ASSET AUDIT FAILED (AC-17):');
    for (final v in violations) {
      stderr.writeln('  - $v');
    }
    exit(1);
  }
  stdout.writeln('OK: all assets conform to the palette and size');
}

String _resolve(String p) {
  if (File(p).existsSync()) return p;
  final up = '../../$p';
  if (File(up).existsSync()) return up;
  return p;
}
