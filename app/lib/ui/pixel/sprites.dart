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

/// Screen-facing storefront → the HD build.
final PixelSprite shop = shopHd;

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

  // HAIR — one smooth cap that FRAMES the face: the hairline sits high at the
  // centre (fringe) and dips lower at the temples, following the head's round
  // shape (no straight sideburn spikes).
  for (var x = cx - hr - 1; x <= cx + hr + 1; x++) {
    final dx = (x - cx).abs();
    var hl =
        hy - 3 + dx; // centre = fringe (high); temples = low (frame cheeks)
    if (hl > hy + 4) hl = hy + 4;
    for (var y = hy - hr - 1; y <= hl; y++) {
      if ((x - cx) * (x - cx) + (y - hy) * (y - hy) <= (hr + 1) * (hr + 1)) {
        c.set(x, y, hBase);
      }
    }
  }
  // soft strand highlight (top-left) + shadow (right side)
  for (var x = cx - 6; x <= cx - 1; x++) {
    c.set(x, hy - hr + 1, hHi);
  }
  c.set(cx - 4, hy - hr + 2, hHi);
  c.set(cx - 3, hy - hr + 3, hHi);
  for (var y = hy - hr + 2; y <= hy + 1; y++) {
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

  // CHEST — a narrow torso that tapers gently to the waist.
  for (var y = 29; y <= 45; y++) {
    final half = 9 - ((y - 29) ~/ 12);
    c.hline(cx - half, y, half * 2, tBase);
    c.set(cx - half, y, tHi);
    c.set(cx + half - 1, y, tSh);
  }
  // SLOPED SHOULDERS — a rounded slope from the neck out to the arms (this is
  // what kills the boxy flat-top look).
  for (var y = 25; y <= 29; y++) {
    final w = 6 + (y - 25) * 2; // 6,8,10,12,14 — widening = なで肩
    c.hline(cx - w, y, w * 2, tBase);
    c.set(cx - w, y, tHi);
    c.set(cx + w - 1, y, tSh);
  }
  // ARMS — hang from the shoulders (their tops rounded by the slope above).
  c.rect(cx - 13, 30, 4, 12, tBase);
  c.set(cx - 13, 30, tHi);
  c.rect(cx + 9, 30, 4, 12, tBase);
  c.set(cx + 12, 30, tSh);
  c.vline(cx - 9, 31, 11, tSh); // armpit seams
  c.vline(cx + 8, 31, 11, tSh);
  c.hline(cx - 13, 40, 4, tSh); // cuffs
  c.hline(cx + 9, 40, 4, tSh);
  c.rect(cx - 13, 42, 4, 4, 'A'); // hands
  c.set(cx - 13, 45, 'z');
  c.rect(cx + 9, 42, 4, 4, 'A');
  c.set(cx + 12, 45, 'z');
  // collar + laced placket + folds.
  for (final p in [
    [cx - 3, 26],
    [cx - 2, 27],
    [cx - 1, 28],
    [cx, 28],
    [cx + 1, 27],
    [cx + 2, 26],
  ]) {
    c.set(p[0], p[1], tHi);
  }
  c.vline(cx, 29, 14, tSh);
  for (var y = 30; y < 42; y += 3) {
    c.set(cx - 1, y, tHi);
    c.set(cx + 1, y, tHi);
  }
  c.vline(cx - 6, 32, 11, tSh);
  c.vline(cx + 5, 32, 11, tSh);

  // BELT + buckle.
  c.rect(cx - 10, 43, 20, 3, 'a');
  c.rampV(cx - 10, 43, 20, 3, ['b', 'a', 'a']);
  c.rect(cx - 2, 43, 4, 3, 'v');
  c.set(cx - 2, 43, 'x');

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

// --- Screen-facing names now point at the HD builds ---
final PixelSprite hero = heroHd;
final PixelSprite customer = villagerHd;
final PixelSprite goddess = _iGoddess();

// --- HD scene props ---
final PixelSprite crate = _iCrate();
final PixelSprite window = _iWindow();
final PixelSprite plant = _iPlant();
final PixelSprite barrel = _iBarrel();

// --- HD icons (24×24) ---
final PixelSprite coin = _iCoin();
final PixelSprite star = _iStar();
final PixelSprite gear = _iGear();
final PixelSprite beaker = _iBeaker();
final PixelSprite factoryIcon = _iFactory();
final PixelSprite storefront = _iStorefront();
final PixelSprite cart = _iCart();
final PixelSprite flame = _iFlame();
final PixelSprite sparkle = _iSparkle();

/// Every named sprite, for the contact-sheet golden + width-invariant test.
final Map<String, PixelSprite> kIconSprites = {
  'coin': coin,
  'star': star,
  'gear': gear,
  'beaker': beaker,
  'factory': factoryIcon,
  'storefront': storefront,
  'cart': cart,
  'flame': flame,
  'sparkle': sparkle,
};

// ------------------------------------------------------------------ icons ----

PixelSprite _iCoin() {
  final c = PixelCanvas(24, 24);
  c.disc(12, 12, 11, 'u'); // rim
  c.discShaded(12, 12, 9, ['x', 'w', 'w', 'v', 'v', 'u']); // face
  c.disc(12, 12, 6, 'v'); // inner emboss ring
  c.discShaded(12, 12, 5, ['x', 'w', 'v']);
  c.set(8, 8, '#');
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iStar() {
  final c = PixelCanvas(24, 24);
  c.starFill(12, 12.5, 11.5, 4.8, 5, ['x', 'w', 'w', 'v', 'v', 'u']);
  c.set(9, 8, '#');
  c.set(10, 8, '#');
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iGear() {
  final c = PixelCanvas(24, 24);
  for (final t in [
    [10, 1],
    [10, 19],
    [1, 10],
    [19, 10],
    [3, 3],
    [17, 3],
    [3, 17],
    [17, 17],
  ]) {
    c.rect(t[0], t[1], 4, 4, 'Q');
  }
  c.discShaded(12, 12, 9, ['S', 'R', 'R', 'Q', 'Q', 'P']);
  c.disc(12, 12, 3, 'P');
  c.disc(12, 12, 2, 'K');
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iBeaker() {
  final c = PixelCanvas(24, 24);
  c.rect(9, 2, 6, 8, 'p'); // neck
  c.rampV(9, 2, 6, 8, ['q', 'p', 'o']);
  c.rect(8, 1, 8, 2, 'i'); // lip
  for (var y = 10; y <= 20; y++) {
    var half = y - 8;
    if (half > 9) half = 9;
    c.hline(12 - half, y, half * 2, 'p');
    if (y >= 15) c.hline(12 - half, y, half * 2, y == 15 ? 'm' : 'l'); // liquid
  }
  c.vline(9, 12, 6, 'q'); // shine
  c.set(14, 18, '#');
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iFactory() {
  final c = PixelCanvas(24, 24);
  c.disc(19, 3, 1, 'S'); // smoke
  c.disc(21, 1, 1, 'R');
  c.rect(16, 4, 4, 7, 'P'); // chimney
  c.set(16, 4, 'R');
  c.rect(2, 10, 20, 10, 'Q');
  c.rampV(2, 10, 20, 10, ['R', 'Q', 'P']);
  for (var x = 3; x < 21; x += 5) {
    c.set(x + 1, 9, 'Q');
    c.set(x + 2, 9, 'Q'); // saw-tooth roof
  }
  for (var wx = 4; wx < 20; wx += 5) {
    c.rect(wx, 13, 3, 4, 'w');
    c.set(wx, 13, 'x');
  }
  c.hline(2, 19, 20, 'P');
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iStorefront() {
  final c = PixelCanvas(24, 24);
  for (var x = 2; x < 22; x++) {
    c.vline(x, 4, 3, (((x - 2) ~/ 3) % 2 == 0) ? 'N' : 'i');
  }
  c.hline(2, 4, 20, 'O');
  c.rect(2, 7, 20, 13, 'g'); // wall
  c.rect(3, 9, 4, 6, 'p'); // window
  c.rampV(3, 9, 4, 6, ['q', 'p', 'o']);
  c.rect(17, 9, 4, 6, 'p');
  c.rampV(17, 9, 4, 6, ['q', 'p', 'o']);
  c.rect(9, 10, 6, 10, 'c'); // door
  c.rampV(9, 10, 6, 10, ['d', 'c', 'b']);
  c.set(13, 15, 'w'); // knob
  c.hline(2, 19, 20, 'b');
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iCart() {
  final c = PixelCanvas(24, 24);
  c.hline(3, 5, 4, 'Q'); // handle
  c.vline(3, 5, 4, 'Q');
  c.rect(6, 8, 13, 8, 'R'); // basket
  c.rampV(6, 8, 13, 8, ['S', 'R', 'Q']);
  for (var x = 9; x < 19; x += 3) {
    c.vline(x, 8, 8, 'Q');
  }
  c.hline(6, 12, 13, 'Q');
  c.disc(9, 19, 2, 'K'); // wheels
  c.set(9, 19, 'Q');
  c.disc(16, 19, 2, 'K');
  c.set(16, 19, 'Q');
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iFlame() {
  final c = PixelCanvas(24, 24);
  for (var y = 3; y <= 21; y++) {
    final w = ((y - 3) * (22 - y)) ~/ 9;
    if (w <= 0) continue;
    c.hline(12 - w, y, w * 2 + 1, y < 9 ? 'N' : 'O'); // outer flame
  }
  for (var y = 9; y <= 21; y++) {
    final w = ((y - 9) * (22 - y)) ~/ 11;
    if (w <= 0) continue;
    c.hline(12 - w, y, w * 2 + 1, 'w'); // inner
  }
  c.disc(12, 17, 2, 'x'); // hot core
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iSparkle() {
  final c = PixelCanvas(24, 24);
  c.starFill(12, 12, 11, 2.4, 4, ['x', 'w', 'v']);
  c.set(9, 9, '#');
  c.set(4, 5, 'w');
  c.set(19, 18, 'w');
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

// ------------------------------------------------------------------ props ----

PixelSprite _iCrate() {
  final c = PixelCanvas(24, 22);
  c.rect(2, 2, 20, 18, 'c');
  c.rampV(2, 2, 20, 18, ['d', 'c', 'b', 'a']);
  c.border(2, 2, 20, 18, 'b');
  c.hline(2, 8, 20, 'b'); // planks
  c.hline(2, 14, 20, 'b');
  c.vline(11, 2, 18, 'b');
  c.line(3, 3, 20, 19, 'M'); // X brace
  c.line(20, 3, 3, 19, 'M');
  c.rect(2, 2, 2, 2, 'Q'); // metal corners
  c.rect(20, 2, 2, 2, 'Q');
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iBarrel() {
  final c = PixelCanvas(22, 24);
  for (var y = 2; y <= 21; y++) {
    final bulge = 2 - ((y - 11).abs() ~/ 5);
    c.hline(3 - bulge, y, 16 + bulge * 2, 'c');
  }
  c.rampH(3, 2, 16, 20, ['b', 'c', 'd', 'c', 'b']);
  c.hline(1, 5, 20, 'a'); // hoops
  c.hline(1, 11, 20, 'a');
  c.hline(1, 17, 20, 'a');
  c.rect(5, 2, 12, 2, 'b'); // top rim
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iWindow() {
  final c = PixelCanvas(28, 22);
  c.rect(0, 0, 28, 20, 'b'); // frame
  c.rect(2, 2, 24, 16, 'c');
  c.rect(3, 3, 22, 14, 't'); // sky
  c.rampV(3, 3, 22, 14, ['r', 's', 't']);
  c.disc(8, 8, 2, '#'); // clouds
  c.disc(11, 9, 2, '#');
  c.disc(19, 12, 2, '#');
  c.vline(13, 3, 14, 'c'); // mullions
  c.hline(3, 10, 22, 'c');
  c.rect(0, 18, 28, 3, 'b'); // sill
  c.rampV(0, 18, 28, 3, ['c', 'b', 'a']);
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

PixelSprite _iPlant() {
  final c = PixelCanvas(24, 28);
  c.discShaded(12, 8, 7, ['V', 'U', 'U', 'T']); // foliage
  c.discShaded(7, 12, 4, ['V', 'U', 'T']);
  c.discShaded(17, 12, 4, ['V', 'U', 'T']);
  c.set(10, 5, 'V');
  c.set(14, 6, 'V');
  c.vline(12, 14, 4, 'T'); // stem
  for (var y = 18; y <= 26; y++) {
    final half = 7 - ((y - 18) ~/ 3);
    c.hline(12 - half, y, half * 2, 'c'); // pot
  }
  c.rampV(5, 18, 14, 9, ['d', 'c', 'b']);
  c.rect(4, 17, 16, 3, 'd'); // rim
  c.outline('K');
  c.selout('K', '@');
  return c.toSprite(kArtPal);
}

// ----------------------------------------------------------------- goddess ---

/// The 女神 who grants the past-life memory (54×74) — a robed, haloed figure
/// matching the character build (small face, hue-shifted robe + gold trim).
PixelSprite _iGoddess() {
  final c = PixelCanvas(54, 74);
  const cx = 27, hy = 18, hr = 9;

  // WINGS behind the shoulders.
  for (var i = 0; i < 12; i++) {
    c.vline(cx - 15 - i ~/ 3, 26 + i, 14 - i, 'J');
    c.vline(cx + 14 + i ~/ 3, 26 + i, 14 - i, 'J');
  }
  c.vline(cx - 16, 28, 10, 'I');
  c.vline(cx + 16, 28, 10, 'I');

  // HALO — a gold ring above the head.
  c.disc(cx, hy - 12, 7, 'w');
  c.disc(cx, hy - 12, 5, '~');
  c.discShaded(cx, hy - 12, 7, ['x', 'w', 'v', 'u']);
  c.disc(cx, hy - 12, 4, '.');

  // HEAD + hair (blonde) + minimal face.
  c.discShaded(cx, hy, hr, ['B', 'A', 'A', 'z', 'z', 'y']);
  const skin = {'B', 'A', 'z', 'y'};
  for (var y = hy - 2; y <= hy + hr - 1; y++) {
    for (var x = cx - hr + 1; x <= cx + hr - 1; x++) {
      if (skin.contains(c.at(x, y))) {
        final t = (y - (hy - 2)) / (hr + 2);
        c.set(x, y, t < 0.7 ? 'A' : (t < 0.9 ? 'z' : 'y'));
      }
    }
  }
  for (var x = cx - hr - 1; x <= cx + hr + 1; x++) {
    final dx = (x - cx).abs();
    var hl = hy - 3 + dx;
    if (hl > hy + 5) hl = hy + 5;
    for (var y = hy - hr - 1; y <= hl; y++) {
      if ((x - cx) * (x - cx) + (y - hy) * (y - hy) <= (hr + 1) * (hr + 1)) {
        c.set(x, y, 'w'); // golden hair
      }
    }
  }
  for (var x = cx - 6; x <= cx - 1; x++) {
    c.set(x, hy - hr + 1, 'x');
  }
  c.set(cx - 3, 19, 'F');
  c.set(cx - 3, 20, 'K');
  c.set(cx + 2, 19, 'F');
  c.set(cx + 2, 20, 'K');
  c.set(cx, 22, 'y');
  c.set(cx - 1, 24, 'M');
  c.set(cx, 24, 'M');
  c.set(cx - 5, 22, 'Z');
  c.set(cx + 4, 22, 'Z');

  // ROBE — a long, flowing white gown with gold trim (no legs).
  c.rect(cx - 3, 26, 6, 3, 'z'); // neck
  for (var y = 28; y <= 70; y++) {
    final half = 5 + ((y - 28) * 12 ~/ 42); // widens toward the hem
    c.hline(cx - half, y, half * 2, 'J');
    c.set(cx - half, y, 'L');
    c.set(cx + half - 1, y, 'I');
  }
  // fold shadows
  c.vline(cx - 4, 34, 34, 'I');
  c.vline(cx + 3, 34, 34, 'I');
  c.vline(cx, 30, 38, 'I');
  // gold trim: collar, waist sash, hem
  for (final p in [
    [cx - 3, 28],
    [cx - 2, 29],
    [cx, 30],
    [cx + 2, 29],
    [cx + 3, 28],
  ]) {
    c.set(p[0], p[1], 'w');
  }
  c.rect(cx - 7, 40, 14, 2, 'w'); // sash
  c.rampV(cx - 7, 40, 14, 2, ['x', 'v']);
  c.hline(cx - 16, 69, 33, 'w'); // hem trim
  c.hline(cx - 16, 70, 33, 'v');
  // sleeves + hands
  c.rect(cx - 9, 30, 4, 12, 'J');
  c.rect(cx + 5, 30, 4, 12, 'J');
  c.rect(cx - 9, 42, 4, 3, 'A');
  c.rect(cx + 5, 42, 4, 3, 'A');

  c.outline('K');
  c.selout('K', '@');
  c.shadow(cx, 73, 18, 1, '-');
  return c.toSprite(kArtPal);
}
