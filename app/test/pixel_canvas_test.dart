import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/ui/pixel/pixel_canvas.dart';

// Unit tests for the procedural drawing engine — guards the primitives the whole
// art set is built on, so a regression fails fast (not just as a golden diff).

const _pal = <String, Color>{
  'r': Color(0xFFFF0000),
  'g': Color(0xFF00FF00),
  'b': Color(0xFF0000FF),
  'K': Color(0xFF000000),
  '@': Color(0xFF888888),
};

void main() {
  test('new canvas is fully transparent', () {
    final c = PixelCanvas(4, 3);
    expect(c.width, 4);
    expect(c.height, 3);
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 4; x++) {
        expect(c.at(x, y), '.');
      }
    }
  });

  test('set/at and out-of-bounds is a silent no-op', () {
    final c = PixelCanvas(3, 3);
    c.set(1, 1, 'r');
    expect(c.at(1, 1), 'r');
    // Out of bounds: neither throws nor writes.
    c.set(-1, 0, 'g');
    c.set(3, 0, 'g');
    c.set(0, 9, 'g');
    expect(c.at(-1, 0), '.');
    expect(c.at(3, 0), '.');
  });

  test('rect / hline / vline fill exactly', () {
    final c = PixelCanvas(6, 6);
    c.rect(1, 1, 3, 2, 'r');
    for (var y = 0; y < 6; y++) {
      for (var x = 0; x < 6; x++) {
        final inside = x >= 1 && x < 4 && y >= 1 && y < 3;
        expect(c.at(x, y), inside ? 'r' : '.', reason: 'at ($x,$y)');
      }
    }
    c.hline(0, 5, 6, 'g');
    for (var x = 0; x < 6; x++) {
      expect(c.at(x, 5), 'g');
    }
    c.vline(5, 0, 6, 'b');
    for (var y = 0; y < 6; y++) {
      expect(c.at(5, y), 'b');
    }
  });

  test('border draws only the frame', () {
    final c = PixelCanvas(5, 5);
    c.border(0, 0, 5, 5, 'r');
    expect(c.at(0, 0), 'r');
    expect(c.at(4, 4), 'r');
    expect(c.at(2, 0), 'r');
    expect(c.at(0, 2), 'r');
    expect(c.at(2, 2), '.'); // interior untouched
  });

  test('rampV applies tones top→bottom', () {
    final c = PixelCanvas(2, 4);
    c.rampV(0, 0, 2, 4, ['r', 'g', 'b', 'K']);
    expect(c.at(0, 0), 'r');
    expect(c.at(0, 1), 'g');
    expect(c.at(0, 2), 'b');
    expect(c.at(0, 3), 'K');
  });

  test('disc is centred and bounded by the radius', () {
    final c = PixelCanvas(11, 11);
    c.disc(5, 5, 3, 'r');
    expect(c.at(5, 5), 'r'); // centre
    expect(c.at(5, 2), 'r'); // top of radius (dist 3)
    expect(c.at(5, 8), 'r'); // bottom
    expect(c.at(2, 5), 'r');
    expect(c.at(8, 5), 'r');
    expect(c.at(0, 0), '.'); // corner is outside r=3
  });

  test('outline wraps the silhouette in transparent neighbours only', () {
    final c = PixelCanvas(5, 5);
    c.set(2, 2, 'r'); // a single lit pixel
    c.outline('K');
    expect(c.at(2, 2), 'r'); // original preserved
    // 8-connected neighbours become outline
    for (final d in const [
      [-1, -1],
      [0, -1],
      [1, -1],
      [-1, 0],
      [1, 0],
      [-1, 1],
      [0, 1],
      [1, 1],
    ]) {
      expect(c.at(2 + d[0], 2 + d[1]), 'K', reason: 'neighbour $d');
    }
    // A far cell stays transparent.
    expect(c.at(0, 0), '.');
  });

  test('selout lightens the lit (top/left) outline edge only', () {
    final c = PixelCanvas(5, 5);
    c.rect(1, 1, 3, 3, 'r');
    c.outline('K');
    c.selout('K', '@');
    // Top edge of the outline (transparent above) becomes '@'.
    expect(c.at(2, 0), '@'); // above the block
    expect(c.at(0, 2), '@'); // left of the block
    // Bottom / right outline stays dark 'K'.
    expect(c.at(2, 4), 'K');
    expect(c.at(4, 2), 'K');
  });

  test('starFill produces a bounded, centred star', () {
    final c = PixelCanvas(24, 24);
    c.starFill(12, 12, 10, 4, 5, ['r']);
    expect(c.at(12, 12), 'r'); // centre filled
    expect(c.at(12, 3), 'r'); // near the top tip
    expect(c.at(0, 0), '.'); // corner empty
    expect(c.at(23, 23), '.');
  });

  test('toSprite yields a rectangular sprite of the canvas size', () {
    final c = PixelCanvas(5, 3);
    c.rect(0, 0, 5, 3, 'r');
    final s = c.toSprite(_pal);
    expect(s.width, 5);
    expect(s.height, 3);
    expect(s.isRectangular, isTrue);
    expect(s.rows.length, 3);
    expect(s.rows.first.length, 5);
    expect(s.palette, _pal);
  });

  test('shadow fills only transparent cells', () {
    final c = PixelCanvas(9, 9);
    c.set(4, 4, 'r'); // an opaque pixel the shadow must not overwrite
    c.shadow(4, 4, 3, 2, 'K');
    expect(c.at(4, 4), 'r'); // preserved
    expect(c.at(1, 4), 'K'); // transparent neighbour within the ellipse
  });
}
