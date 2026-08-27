// Sprite rows are composed with `*`/`+` on purpose (each row's width is then
// provably correct); interpolation would obscure that.
// ignore_for_file: prefer_interpolation_to_compose_strings
import 'package:flutter/material.dart';

import 'pixel_art.dart';

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

// --- Hero: the 24h 異世界コンビニ商会 storefront (32×20). Built band-by-band
// with string expressions so every row is provably 32 wide. ---
final _glassRow = 'nn' + 'l' * 8 + 'nn' + 'lllMMlll' + 'nn' + 'l' * 8; // 30
final PixelSprite shop = PixelSprite([
  '.' * 32,
  'k' + 'D' * 30 + 'k', // roof
  'k' + 'G' * 30 + 'k', // sign
  'k' + 'G' * 13 + 'W' * 4 + 'G' * 13 + 'k', // sign logo plate
  'k' + 'G' * 30 + 'k',
  'k' + 'D' * 30 + 'k', // sign shadow
  'k' + ('rW' * 15) + 'k', // striped awning
  'k' + 'n' * 30 + 'k', // wall
  'k' + _glassRow + 'k',
  'k' + _glassRow + 'k',
  'k' + _glassRow + 'k',
  'k' + _glassRow + 'k',
  'k' + _glassRow + 'k',
  'k' + _glassRow + 'k',
  'k' + 'M' * 30 + 'k', // threshold
  'k' + 'm' * 30 + 'k', // floor
  'k' + 'm' * 30 + 'k',
  'k' * 32, // base
  '.' + 'X' * 30 + '.', // ground shadow
  '.' * 32,
], kPal);

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
