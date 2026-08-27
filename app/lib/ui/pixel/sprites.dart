// Sprite rows are composed with `*`/`+` on purpose (each row's width is then
// provably correct); interpolation would obscure that.
// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';

import 'pixel_art.dart';
import 'pixel_canvas.dart';

/// Shared warm/retro palette (カイロ系). One-char keys keep the sprite rows
/// compact; `.` / ` ` are transparent.
const Map<String, Color> kPal = {
  'k': Color(0xFF2E2016), // outline (dark brown)
  'w': Color(0xFFFFFFFF), // white
  'W': Color(0xFFF1E7CE), // cream
  'g': Color(0xFFF2C33C), // gold
  'y': Color(0xFFFFE39A), // light gold
  'o': Color(0xFFE4892B), // orange
  'r': Color(0xFFD75A4A), // red
  'R': Color(0xFFA23B2E), // dark red
  'b': Color(0xFF4E8FCB), // blue (uniform)
  'B': Color(0xFF305F97), // dark blue
  's': Color(0xFFF4CBA0), // skin
  'S': Color(0xFFD9A578), // skin shadow
  'h': Color(0xFF6B4A2B), // hair
  'G': Color(0xFF35A45B), // green (sign)
  'D': Color(0xFF1F7A40), // dark green
  'l': Color(0xFFC4E7F2), // glass
  'L': Color(0xFF93C6D9), // glass shadow
  'n': Color(0xFFE7D6AE), // wall beige
  'N': Color(0xFFC8B488), // wall shadow
  'm': Color(0xFFA66E3C), // wood
  'M': Color(0xFF7C4E2A), // wood dark
  'x': Color(0xFFC3BBAB), // light gray
  'X': Color(0xFF6E665A), // dark gray
  'e': Color(0xFF79C07A), // leaf green
  'p': Color(0xFFE88FA6), // pink
};

/// HIGH-FIDELITY palette (v3) — HUE-SHIFTED tonal ramps per material (the
/// technique that separates living pixel art from flat clip art): as a ramp
/// brightens, hue rotates ~toward warm/yellow and desaturates; shadows rotate
/// cooler and keep more saturation (Slynyrd/Derek Yu). Light source top-left.
/// Single-char keys, dark→light; `.`/` ` transparent.
const Map<String, Color> kArtPal = {
  'K': Color(0xFF2B2230), // outline (dark desaturated plum, not pure black)
  '@': Color(0xFF574A55), // lit outline (selout — top/left edges)
  // wood a→e  (shadow red-brown → highlight warm tan)
  'a': Color(0xFF462A1F), 'b': Color(0xFF6A4327), 'c': Color(0xFF8C5B33),
  'd': Color(0xFFAE7B42), 'e': Color(0xFFCE9E57),
  // wall plaster f→i
  'f': Color(0xFFA68A55), 'g': Color(0xFFC5AB76), 'h': Color(0xFFDCC793),
  'i': Color(0xFFF1E6BB),
  // green (roof/sign) j→m  (shadow teal → highlight yellow-green)
  'j': Color(0xFF1B6B4E), 'k': Color(0xFF2A8B4E), 'l': Color(0xFF4EA84C),
  'm': Color(0xFF82C64C),
  // glass n→q  (shadow blue → highlight pale cyan)
  'n': Color(0xFF5F97BE), 'o': Color(0xFF8FC6D9), 'p': Color(0xFFBBE2EF),
  'q': Color(0xFFE0F4FA),
  // sky (window view) r→t
  'r': Color(0xFF79B8E4), 's': Color(0xFFABD8F2), 't': Color(0xFFDCEFFB),
  // gold u→x  (shadow orange → highlight pale yellow)
  'u': Color(0xFFA5661C), 'v': Color(0xFFD2972A), 'w': Color(0xFFF0C33C),
  'x': Color(0xFFFFE788),
  // skin y,z,A,B  (shadow rosy-red → highlight warm cream)
  'y': Color(0xFFC06E5A), 'z': Color(0xFFE0996E), 'A': Color(0xFFF2C295),
  'B': Color(0xFFFFE7C4),
  // hair C→E  (dark red-brown → warm brown)
  'C': Color(0xFF382116), 'D': Color(0xFF5C3C22), 'E': Color(0xFF8A5E2E),
  // cloth blue F→H  (shadow indigo → highlight cyan-blue)
  'F': Color(0xFF374A88), 'G': Color(0xFF3F72B0), 'H': Color(0xFF6BAEDA),
  // apron/white cloth I,J,L  (cool shadow → warm white)
  'I': Color(0xFFC6C7D0), 'J': Color(0xFFE6E7EC), 'L': Color(0xFFFBFBF7),
  // red (awning/tunic) M→O  (shadow crimson-plum → highlight orange)
  'M': Color(0xFF8B2A38), 'N': Color(0xFFC0432F), 'O': Color(0xFFE0714A),
  // gray/metal P→S  (shadow blue-gray → highlight warm gray)
  'P': Color(0xFF4E5461), 'Q': Color(0xFF7A7B78), 'R': Color(0xFFA9A79B),
  'S': Color(0xFFD0CCBE),
  // leaf T→V  (shadow teal → highlight yellow-green)
  'T': Color(0xFF368141), 'U': Color(0xFF61B05F), 'V': Color(0xFF8FC96E),
  // accents
  'Z': Color(0xFFE888A6), // pink (cheeks)
  '#': Color(0xFFFFFFFF), // pure white highlight
  '-': Color(0x33000000), // soft shadow
  '~': Color(0x1E000000), // faint shadow
};

// --- Hero: the 24h 異世界コンビニ商会 storefront, drawn procedurally at high
// resolution (104×78) with shading ramps, awning scallop, glazed windows with
// product shelves + reflections, and a stone base. See _buildShop below. ---
final PixelSprite shopHd = _buildShop();

// Low-res storefront (32×20) still wired into the live screens; the HD build
// above is being reviewed before the screen-by-screen migration.
final String _ogGlass =
    'nn' + 'l' * 8 + 'nn' + 'lllMMlll' + 'nn' + 'l' * 8; // 30
final PixelSprite shop = PixelSprite([
  '.' * 32,
  'k' + 'D' * 30 + 'k',
  'k' + 'G' * 30 + 'k',
  'k' + 'G' * 13 + 'W' * 4 + 'G' * 13 + 'k',
  'k' + 'G' * 30 + 'k',
  'k' + 'D' * 30 + 'k',
  'k' + ('rW' * 15) + 'k',
  'k' + 'n' * 30 + 'k',
  'k' + _ogGlass + 'k',
  'k' + _ogGlass + 'k',
  'k' + _ogGlass + 'k',
  'k' + _ogGlass + 'k',
  'k' + _ogGlass + 'k',
  'k' + _ogGlass + 'k',
  'k' + 'M' * 30 + 'k',
  'k' + 'm' * 30 + 'k',
  'k' + 'm' * 30 + 'k',
  'k' * 32,
  '.' + 'X' * 30 + '.',
  '.' * 32,
], kPal);

/// HD townsfolk — one 48×54 `_person` build recolored per role: skin/hair/cloth
/// ramps, a real face, uniform folds, selective outline. `heroHd` is the 店主.
final PixelSprite heroHd = _person(
  hair: ['C', 'D', 'E'],
  top: ['F', 'G', 'H'],
  pants: ['F', 'G'],
  apron: true,
  nameTag: true,
);
final PixelSprite villagerHd = _person(
  hair: ['M', 'N', 'O'],
  top: ['T', 'U', 'V'],
  pants: ['a', 'b'],
);
final PixelSprite ladyHd = _person(
  hair: ['u', 'v', 'w'],
  top: ['M', 'N', 'O'],
  pants: ['M', 'N'],
);
final PixelSprite elderHd = _person(
  hair: ['P', 'Q', 'R'],
  top: ['b', 'c', 'd'],
  pants: ['P', 'Q'],
);
final PixelSprite adventurerHd = _person(
  hair: ['C', 'D', 'E'],
  top: ['T', 'U', 'V'],
  pants: ['a', 'b'],
  cloak: true,
  cloakRamp: ['M', 'N', 'O'],
);

/// A glazed display window with wooden frame, product shelves and a reflection.
void _shopWindow(PixelCanvas c, int x, int y, int w, int h) {
  c.rect(x - 3, y - 3, w + 6, h + 6, 'a'); // outer frame (dark wood)
  c.rect(x - 2, y - 2, w + 4, h + 4, 'c');
  c.hline(x - 2, y - 2, w + 4, 'd'); // lit top of frame
  c.rect(x, y, w, h, 'p'); // glass
  c.rampV(x, y, w, h, ['q', 'p', 'o', 'n']); // sky-lit gradient
  // three product shelves with little colored goods
  const goods = ['N', 'w', 'H', 'O', 'U', 'M'];
  for (var s = 0; s < 3; s++) {
    final sy = y + 4 + s * ((h - 6) ~/ 3);
    for (var ix = x + 2; ix < x + w - 2; ix += 5) {
      final col = goods[((ix + sy) ~/ 5) % goods.length];
      c.rect(ix, sy, 3, 4, col);
      c.set(ix, sy, 'K'); // top-left shade of each good
    }
    c.hline(x, sy + 4, w, 'b'); // shelf board
    c.hline(x, sy + 5, w, 'a');
  }
  // diagonal glass reflection (subtle)
  for (var i = 0; i < h; i++) {
    c.set(x + 3 + i, y + i, 'q');
    c.set(x + 4 + i, y + i, '#');
  }
  // window cross (mullions) then outline
  c.vline(x + w ~/ 2, y, h, 'c');
  c.hline(x, y + h ~/ 2, w, 'c');
  c.border(x - 3, y - 3, w + 6, h + 6, 'K');
}

PixelSprite _buildShop() {
  final c = PixelCanvas(104, 78);

  // ROOF — a thick eave, wider than the body, lit on top, shadowed beneath.
  c.rect(2, 3, 100, 8, 'k');
  c.rampV(2, 3, 100, 8, ['m', 'l', 'k', 'j']);
  c.hline(2, 3, 100, 'm');
  c.rect(2, 11, 100, 2, 'j');
  c.border(2, 3, 100, 10, 'K');

  // SIGNBOARD — green band with a beveled cream plaque + logo + gold rule.
  c.rect(6, 13, 92, 13, 'k');
  c.rampV(6, 13, 92, 13, ['l', 'k', 'j']);
  c.rect(14, 14, 76, 10, 'a');
  c.rect(15, 15, 74, 8, 'h');
  c.rampV(15, 15, 74, 8, ['i', 'h', 'g']);
  c.hline(15, 15, 74, 'i');
  c.discShaded(24, 19, 4, ['m', 'l', 'k', 'j']); // logo mark
  c.hline(33, 18, 50, 'w'); // gold rule
  c.hline(33, 19, 50, 'v');
  c.hline(33, 20, 50, 'u');
  c.vline(6, 13, 13, 'K');
  c.vline(97, 13, 13, 'K');

  // AWNING — red/cream stripes with a scalloped valance and a cast shadow.
  const ay = 27;
  for (var i = 8; i < 96; i++) {
    final red = (((i - 8) ~/ 7) % 2) == 0;
    c.vline(i, ay, 6, red ? 'N' : 'i');
  }
  c.hline(8, ay, 88, 'O'); // lit front lip
  c.hline(8, ay + 5, 88, '-'); // underside shadow
  for (var s = 8; s < 96; s += 7) {
    final red = (((s - 8) ~/ 7) % 2) == 0;
    for (var k = 0; k < 3; k++) {
      c.hline(s + k, ay + 6 + k, 7 - 2 * k, red ? 'M' : 'g');
    }
  }
  c.vline(8, ay, 6, 'K');
  c.vline(95, ay, 6, 'K');

  // WALL + STOREFRONT — plaster wall, two display windows and a central door.
  const wy = 35, wh = 33;
  c.rect(6, wy, 92, wh, 'g');
  for (var y = wy + 3; y < wy + wh; y += 5) {
    c.hline(8, y, 88, 'f'); // faint plaster courses
  }
  _shopWindow(c, 13, wy + 4, 26, 24);
  _shopWindow(c, 65, wy + 4, 26, 24);
  // central double door
  const dx = 45, dw = 14;
  c.rect(dx - 3, wy, dw + 6, wh, 'a');
  c.rect(dx - 2, wy + 1, dw + 4, wh - 1, 'c');
  c.rect(dx, wy + 2, dw, wh - 6, 'p');
  c.rampV(dx, wy + 2, dw, wh - 6, ['q', 'p', 'o', 'n']);
  c.vline(dx + dw ~/ 2 - 1, wy + 2, wh - 6, 'c');
  c.vline(dx + dw ~/ 2, wy + 2, wh - 6, 'b');
  c.rect(dx + dw ~/ 2 - 3, wy + 15, 2, 4, 'w'); // handles
  c.rect(dx + dw ~/ 2 + 1, wy + 15, 2, 4, 'w');
  c.rect(dx + 2, wy + 5, dw - 4, 4, 'k'); // OPEN placard
  c.hline(dx + 2, wy + 5, dw - 4, 'm');
  c.rect(dx, wy + wh - 4, dw, 4, 'b'); // kick plate
  c.rampV(dx, wy + wh - 4, dw, 4, ['d', 'c', 'b']);
  for (var i = 0; i < wh - 6; i++) {
    c.set(dx + 2 + i, wy + 2 + i, 'q'); // reflection
  }
  c.border(dx - 3, wy, dw + 6, wh, 'K');
  c.border(6, wy, 92, wh, 'K');

  // BASE — wood threshold over a stone plinth.
  const by = wy + wh; // 68
  c.rect(6, by, 92, 5, 'b');
  c.rampV(6, by, 92, 5, ['d', 'c', 'b', 'a']);
  c.hline(6, by, 92, 'e');
  c.rect(4, by + 5, 96, 3, 'Q');
  c.rampV(4, by + 5, 96, 3, ['R', 'Q', 'P']);
  c.border(4, by + 5, 96, 3, 'K');

  // GROUND SHADOW.
  c.shadow(52, 77, 48, 2, '-');
  return c.toSprite(kArtPal);
}

/// One JRPG-style character chip (54×74, ~4 heads tall) — katarazu風: small
/// minimal face, layered outfit with folds, belt + buckle, tall boots. [hair]/
/// [top] are [shadow, base, highlight] ramps; [pants] is [base, highlight].
/// Optional white [apron] + gold [nameTag], and a [cloak] (with [cloakRamp]).
PixelSprite _person({
  required List<String> hair,
  required List<String> top,
  required List<String> pants,
  bool apron = false,
  bool nameTag = false,
  bool cloak = false,
  List<String> cloakRamp = const ['M', 'N', 'O'],
  List<String> boots = const ['a', 'b', 'c'],
}) {
  final hSh = hair[0], hBase = hair[1], hHi = hair[2];
  final tSh = top[0], tBase = top[1], tHi = top[2];
  final pBase = pants[0], pHi = pants[1];
  final c = PixelCanvas(54, 74);
  const cx = 27, hy = 14, hr = 9;

  // CLOAK — a draped cape behind the body (drawn first).
  if (cloak) {
    final k0 = cloakRamp[0], k1 = cloakRamp[1], k2 = cloakRamp[2];
    for (var y = 24; y <= 64; y++) {
      final half = 13 - ((y - 24) ~/ 13);
      c.hline(cx - half, y, half * 2, k1);
      c.set(cx - half, y, k0);
      c.set(cx + half - 1, y, k2);
    }
    c.vline(cx - 7, 28, 34, k0);
    c.vline(cx, 28, 34, k2);
    c.vline(cx + 6, 28, 34, k0);
    for (var y = 62; y <= 66; y++) {
      final ins = y - 62;
      c.hline(cx - 11 + ins, y, 22 - 2 * ins, k0);
    }
  }

  // HEAD — small, top-left-lit, then flattened to a soft front-lit face.
  c.discShaded(cx, hy, hr, ['B', 'A', 'A', 'z', 'z', 'y']);
  c.rect(17, hy, 2, 4, 'z');
  c.rect(36, hy, 2, 4, 'z');
  const skin = {'B', 'A', 'z', 'y'};
  for (var y = hy - 2; y <= hy + hr - 1; y++) {
    for (var x = cx - hr + 1; x <= cx + hr - 1; x++) {
      if (skin.contains(c.at(x, y))) {
        final t = (y - (hy - 2)) / (hr + 2);
        c.set(x, y, t < 0.7 ? 'A' : (t < 0.9 ? 'z' : 'y'));
      }
    }
  }

  // HAIR — scalp, swept fringe, sideburns, strand highlights + shadow side.
  for (var y = hy - hr; y <= hy - 1; y++) {
    for (var x = cx - hr; x <= cx + hr; x++) {
      if ((x - cx) * (x - cx) + (y - hy) * (y - hy) <= hr * hr) {
        c.set(x, y, hBase);
      }
    }
  }
  for (var x = cx - 8; x <= cx + 8; x++) {
    final dip = hy - 1 + (2 - ((x - (cx - 3)).abs() ~/ 4)).clamp(0, 2);
    for (var y = hy - 1; y <= dip; y++) {
      if ((x - cx) * (x - cx) + (y - hy) * (y - hy) <= (hr + 1) * (hr + 1)) {
        c.set(x, y, hBase);
      }
    }
  }
  c.vline(cx - hr + 1, hy - 2, 7, hBase);
  c.vline(cx + hr - 1, hy - 2, 7, hBase);
  for (var x = cx - 6; x <= cx - 1; x++) {
    c.set(x, hy - hr + 1, hHi);
  }
  c.set(cx - 4, hy - hr + 2, hHi);
  c.set(cx + 2, hy - hr + 2, hHi);
  for (var y = hy - hr + 2; y <= hy - 3; y++) {
    c.set(cx + hr - 1, y, hSh);
  }

  // FACE — minimal (FE-style): 1px eyes, tiny nose + mouth, faint blush.
  c.set(cx - 3, 15, 'F');
  c.set(cx - 3, 16, 'K');
  c.set(cx + 2, 15, 'F');
  c.set(cx + 2, 16, 'K');
  c.set(cx - 4, 14, hSh);
  c.set(cx + 3, 14, hSh);
  c.set(cx, 18, 'y');
  c.set(cx - 1, 20, 'M');
  c.set(cx, 20, 'M');
  c.set(cx - 5, 18, 'Z');
  c.set(cx + 4, 18, 'Z');

  // NECK.
  c.rect(cx - 3, 22, 6, 3, 'z');
  c.hline(cx - 3, 22, 6, 'A');

  // TORSO (tunic) — trapezoid, collar, laced placket, fold shading.
  for (var y = 25; y <= 45; y++) {
    final half = 12 - ((y - 25) ~/ 8);
    c.hline(cx - half, y, half * 2, tBase);
    c.set(cx - half, y, tHi);
    c.set(cx + half - 1, y, tSh);
  }
  for (final p in [
    [cx - 3, 25],
    [cx - 2, 26],
    [cx - 1, 27],
    [cx, 27],
    [cx + 1, 26],
    [cx + 2, 25],
  ]) {
    c.set(p[0], p[1], tHi); // collar
  }
  c.vline(cx, 27, 16, tSh); // placket
  for (var y = 28; y < 43; y += 3) {
    c.set(cx - 1, y, tHi);
    c.set(cx + 1, y, tHi); // lacing stitches
  }
  c.vline(cx - 6, 30, 13, tSh); // folds
  c.vline(cx + 5, 30, 13, tSh);
  c.hline(cx - 11, 26, 3, tSh); // shoulder seams
  c.hline(cx + 8, 26, 3, tSh);

  // BELT + buckle.
  c.rect(cx - 11, 43, 22, 3, 'a');
  c.rampV(cx - 11, 43, 22, 3, ['b', 'a', 'a']);
  c.rect(cx - 2, 43, 4, 3, 'v');
  c.set(cx - 2, 43, 'x');

  // SLEEVES + cuffs + hands.
  c.rect(cx - 13, 26, 4, 13, tBase);
  c.set(cx - 13, 26, tHi);
  c.hline(cx - 13, 38, 4, tSh);
  c.rect(cx + 9, 26, 4, 13, tBase);
  c.set(cx + 12, 26, tSh);
  c.hline(cx + 9, 38, 4, tSh);
  c.rect(cx - 13, 39, 4, 5, 'A');
  c.set(cx - 13, 43, 'z');
  c.rect(cx + 9, 39, 4, 5, 'A');
  c.set(cx + 12, 43, 'z');

  // APRON (optional) — bib + skirt with folds + pocket.
  if (apron) {
    c.rect(cx - 5, 30, 10, 3, 'J');
    c.rect(cx - 8, 33, 16, 13, 'J');
    c.rampV(cx - 8, 33, 16, 13, ['L', 'J', 'J', 'I']);
    c.border(cx - 8, 33, 16, 13, 'I');
    c.hline(cx - 8, 34, 16, 'I');
    c.hline(cx - 5, 40, 10, 'I');
    c.vline(cx, 33, 13, 'I');
  }
  if (nameTag) {
    c.rect(cx + 1, 30, 4, 2, 'w');
    c.set(cx + 1, 30, 'x');
  }

  // LEGS (trousers) with fold highlights.
  c.rect(cx - 8, 46, 7, 18, pBase);
  c.rect(cx + 1, 46, 7, 18, pBase);
  c.vline(cx - 8, 46, 18, pHi);
  c.vline(cx + 1, 46, 18, pHi);
  for (var y = 50; y < 62; y += 4) {
    c.set(cx - 5, y, pHi);
    c.set(cx + 4, y, pHi);
  }

  // BOOTS (tall) — cuff, shaft ramp, dark sole.
  final b0 = boots[0], b1 = boots[1], b2 = boots[2];
  c.rect(cx - 9, 61, 8, 12, b1);
  c.rect(cx + 1, 61, 8, 12, b1);
  c.rampV(cx - 9, 61, 8, 12, [b2, b1, b1, b0]);
  c.rampV(cx + 1, 61, 8, 12, [b2, b1, b1, b0]);
  c.hline(cx - 9, 61, 8, b2); // cuff
  c.hline(cx + 1, 61, 8, b2);
  c.hline(cx - 9, 72, 8, 'K'); // sole
  c.hline(cx + 1, 72, 8, 'K');

  c.outline('K');
  c.selout('K', '@');
  c.shadow(cx, 73, 15, 1, '-');
  return c.toSprite(kArtPal);
}

// --- The reincarnated コンビニSV protagonist, chibi (16×19). ---
final PixelSprite hero = PixelSprite([
  '.' * 3 + 'k' * 10 + '.' * 3,
  '.' * 3 + 'k' + 'h' * 8 + 'k' + '.' * 3,
  '.' * 2 + 'k' + 'h' * 10 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'h' * 2 + 's' * 6 + 'h' * 2 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 's' * 10 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'ss' + 'k' + 'ssss' + 'k' + 'ss' + 'k' + '.' * 2, // eyes
  '.' * 2 + 'k' + 's' * 4 + 'p' * 2 + 's' * 4 + 'k' + '.' * 2, // cheeks
  '.' * 2 + 'k' + 's' * 10 + 'k' + '.' * 2,
  '.' * 3 + 'k' + 's' * 8 + 'k' + '.' * 3, // chin
  '.' * 2 + 'k' + 'b' * 10 + 'k' + '.' * 2, // shoulders
  '.' * 2 + 'k' + 'b' * 2 + 'W' * 6 + 'b' * 2 + 'k' + '.' * 2, // apron
  '.' * 2 + 'k' + 'b' + 'W' * 8 + 'b' + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'b' + 'W' * 8 + 'b' + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'b' * 2 + 'W' * 6 + 'b' * 2 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'b' * 10 + 'k' + '.' * 2, // waist
  '.' * 2 + 'k' + 'B' * 4 + 'kk' + 'B' * 4 + 'k' + '.' * 2, // legs
  '.' * 2 + 'k' + 'B' * 4 + 'kk' + 'B' * 4 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'M' * 4 + 'kk' + 'M' * 4 + 'k' + '.' * 2, // shoes
  '.' * 3 + 'X' * 10 + '.' * 3, // shadow
], kPal);

// --- A townsperson customer (16×19), same build as the hero, recolored. ---
final PixelSprite customer = PixelSprite([
  '.' * 3 + 'k' * 10 + '.' * 3,
  '.' * 3 + 'k' + 'o' * 8 + 'k' + '.' * 3, // orange hair
  '.' * 2 + 'k' + 'o' * 10 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'o' * 2 + 's' * 6 + 'o' * 2 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 's' * 10 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'ss' + 'k' + 'ssss' + 'k' + 'ss' + 'k' + '.' * 2,
  '.' * 2 + 'k' + 's' * 4 + 'p' * 2 + 's' * 4 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 's' * 10 + 'k' + '.' * 2,
  '.' * 3 + 'k' + 's' * 8 + 'k' + '.' * 3,
  '.' * 2 + 'k' + 'r' * 10 + 'k' + '.' * 2, // red tunic
  '.' * 2 + 'k' + 'r' * 10 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'r' * 3 + 'R' * 4 + 'r' * 3 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'r' * 10 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'r' * 10 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'r' * 10 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'M' * 4 + 'kk' + 'M' * 4 + 'k' + '.' * 2, // brown pants
  '.' * 2 + 'k' + 'M' * 4 + 'kk' + 'M' * 4 + 'k' + '.' * 2,
  '.' * 2 + 'k' + 'X' * 4 + 'kk' + 'X' * 4 + 'k' + '.' * 2, // shoes
  '.' * 3 + 'X' * 10 + '.' * 3,
], kPal);

/// The 女神 who grants the past-life memory (14×17) — onboarding 転生 beat.
const PixelSprite goddess = PixelSprite([
  '....gggggg....',
  '...g......g...',
  '....kkkkkk....',
  '...kyyyyyyk...',
  '...kyssssyk...',
  '...kskssksk...',
  '...kssssssk...',
  '....kssssk....',
  '.wwkwwwwwwkww.',
  '.wwkwwwwwwkww.',
  '...kwwwwwwk...',
  '...kwwwwwwk...',
  '...kwGGGGwk...',
  '...kwwwwwwk...',
  '...kwwwwwwk...',
  '...kkkkkkkk...',
  '....XXXXXX....',
], kPal);

/// A wooden crate (12×12) — a scene prop / stock.
const PixelSprite crate = PixelSprite([
  '............',
  'kkkkkkkkkkkk',
  'kmmmmmmmmmmk',
  'kMmmmmmmmMmk',
  'kmMmmmmmMmmk',
  'kmmMmmmMmmmk',
  'kmmmMMMMmmmk',
  'kmmmMMMMmmmk',
  'kmmMmmmMmmmk',
  'kMmmmmmmmMmk',
  'kkkkkkkkkkkk',
  '............',
], kPal);

/// A wall window looking out on a bright sky (14×10) — depth on the back wall.
const PixelSprite window = PixelSprite([
  'kkkkkkkkkkkkkk',
  'kMMMMMMMMMMMMk',
  'kMllllllllllMk',
  'kMlwwwlllwwlMk',
  'kMllllllllllMk',
  'kMlllllwwwllMk',
  'kMllllllllllMk',
  'kMMMMMMMMMMMMk',
  'kkkkkkkkkkkkkk',
  '..MM......MM..',
], kPal);

/// A potted plant (12×14) — a scene prop / warmth.
const PixelSprite plant = PixelSprite([
  '...ee..ee...',
  '..eeeeeeee..',
  '.eeeeeeeeee.',
  '.eeDeeeeDee.',
  '.eeeeeeeeee.',
  '..eeeeeeee..',
  '...eeeeee...',
  '.....DD.....',
  '....kkkk....',
  '...kmmmmk...',
  '...kmmmmk...',
  '...kMMMMk...',
  '...kkkkkk...',
  '............',
], kPal);

// --- 12×12 icons (replace every emoji / Material glyph in the HUD & nav). ---

/// 資金 — a gold coin.
const PixelSprite coin = PixelSprite([
  '....kkkk....',
  '..kkyyyykk..',
  '.kyyggggyyk.',
  '.kyggggggyk.',
  'kyggggggggyk',
  'kyggggggggyk',
  'kyggggggggyk',
  'kyggggggggyk',
  '.kyggggggyk.',
  '.kyyggggyyk.',
  '..kkyyyykk..',
  '....kkkk....',
], kPal);

/// 名声 — a star.
const PixelSprite star = PixelSprite([
  '.....kk.....',
  '.....gg.....',
  '....kggk....',
  '....kggk....',
  'kkkkggggkkkk',
  '.kggggggggk.',
  '..kgggggggk.',
  '..kggggggk..',
  '.kggk..kggk.',
  '.kgk....kgk.',
  'kkk......kkk',
  '............',
], kPal);

/// 設定 — a gear.
const PixelSprite gear = PixelSprite([
  '...k.kk.k...',
  '...kkXXkk...',
  '.kkkXXXXkkk.',
  '.kXXXXXXXXk.',
  'kXXXkkkkXXXk',
  'XXXkkwwkkXXX',
  'XXXkkwwkkXXX',
  'kXXXkkkkXXXk',
  '.kXXXXXXXXk.',
  '.kkkXXXXkkk.',
  '...kkXXkk...',
  '...k.kk.k...',
], kPal);

/// 開発 — a science beaker (フラスコ).
const PixelSprite beaker = PixelSprite([
  '...kkkkk....',
  '...kwwwk....',
  '...klllk....',
  '...klllk....',
  '..kklllkk...',
  '..kleeelk...',
  '.kkeeeeekk..',
  '.kleeeeelk..',
  '.kleeeeelk..',
  '.kleeeeelk..',
  '.kkkkkkkkk..',
  '............',
], kPal);

/// 生産 — a factory.
const PixelSprite factory = PixelSprite([
  '.........k..',
  '......kkkk..',
  '......kXXk..',
  '..k...kXXk..',
  '..kk..kXXk..',
  '..kXkkkXXkk.',
  '.kXXXXXXXXXk',
  'kXwwXwwXwwXk',
  'kXwwXwwXwwXk',
  'kXXXXXXXXXXk',
  'kkkkkkkkkkkk',
  '............',
], kPal);

/// 販売 — a market stall / storefront.
const PixelSprite storefront = PixelSprite([
  '.kkkkkkkkkk.',
  'krWrWrWrWrWk', // striped awning
  'krWrWrWrWrWk',
  'kkkkkkkkkkkk',
  'knnnnnnnnnnk',
  'knllknnllnnk',
  'knllknnllnnk',
  'knnnknnnnnk.',
  'knnnknnnnnnk',
  'knnnknnnnnnk',
  'kkkkkkkkkkkk',
  '............',
], kPal);

/// 発注 — a shopping cart.
const PixelSprite cart = PixelSprite([
  'kk..........',
  'kk...kkkkkk.',
  'kk..kmmmmmk.',
  'kk.kmmmmmk..',
  'kkkmmmmmk...',
  'kmmmmmmk....',
  'kkkkkkkk....',
  '.k....k.....',
  'kkk..kkk....',
  'kXk..kXk....',
  'kkk..kkk....',
  '............',
], kPal);

/// 流行 — a flame.
const PixelSprite flame = PixelSprite([
  '.....k......',
  '.....ko.....',
  '....koo.....',
  '....kook....',
  '...koook....',
  '...koyok....',
  '..koyyok....',
  '..koyyyok...',
  '.koyywyyok..',
  '.koyyyyyok..',
  '..kooooook..',
  '...kkkkkk...',
], kPal);

/// 発明 — a sparkle.
const PixelSprite sparkle = PixelSprite([
  '.....kk.....',
  '.....yy.....',
  '....kyyk....',
  '..k.kyyk.k..',
  '.kkkkyykkkk.',
  'kyyyyyyyyyyk',
  'kyyyyyyyyyyk',
  '.kkkkyykkkk.',
  '..k.kyyk.k..',
  '....kyyk....',
  '.....yy.....',
  '.....kk.....',
], kPal);

/// Every named sprite, for the contact-sheet golden + width-invariant test.
const Map<String, PixelSprite> kIconSprites = {
  'coin': coin,
  'star': star,
  'gear': gear,
  'beaker': beaker,
  'factory': factory,
  'storefront': storefront,
  'cart': cart,
  'flame': flame,
  'sparkle': sparkle,
};
