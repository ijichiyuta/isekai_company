import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/entitlements.dart';
import 'package:isekai_app/game/game_controller.dart';
import 'package:isekai_app/game/providers.dart';
import 'package:isekai_app/game/tick_clock.dart';
import 'package:isekai_app/ui/develop_screen.dart';
import 'package:isekai_app/ui/event_dialog.dart';
import 'package:isekai_app/ui/invention_overlay.dart';
import 'package:isekai_app/ui/how_to_play_screen.dart';
import 'package:isekai_app/ui/main_screen.dart';
import 'package:isekai_app/ui/title_screen.dart';
import 'package:isekai_app/ui/onboarding.dart';
import 'package:isekai_app/ui/order_screen.dart';
import 'package:isekai_app/ui/production_screen.dart';
import 'package:isekai_app/ui/sales_screen.dart';
import 'package:isekai_app/ui/settings_screen.dart';
import 'package:isekai_app/ui/soul_memory_screen.dart';
import 'package:isekai_app/ui/theme.dart';
import 'package:isekai_core/isekai_core.dart';

import 'helpers.dart';

// Renders the real UI, seeded to a plausible MID-GAME state, to PNGs so the
// game can be reviewed screen-by-screen. macOS-only (host font + renderer), so
// CI on Linux skips it. Run: flutter test test/screens_golden_test.dart --update-goldens

Future<void> _loadFont(String family, List<String> candidates) async {
  for (final path in candidates) {
    final f = File(path);
    if (!f.existsSync()) continue;
    final bytes = f.readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    await loader.load();
    return;
  }
}

/// Real fonts so the goldens read like the shipping app, not tofu boxes:
/// Hiragino (JP text), MaterialIcons (every UI glyph), Apple Color Emoji
/// (🏪🔥✨…). The MaterialIcons path is resolved from FLUTTER_ROOT with a
/// Homebrew-cask fallback — host-specific, but these goldens are macOS-only.
Future<void> _loadFonts() async {
  await _loadFont('Hiragino', const [
    '/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc',
    '/System/Library/Fonts/Hiragino Sans GB.ttc',
  ]);
  await _loadFont('AppleColorEmoji', const [
    '/System/Library/Fonts/Apple Color Emoji.ttc',
  ]);
  final root = Platform.environment['FLUTTER_ROOT'];
  await _loadFont('MaterialIcons', [
    if (root != null)
      '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

/// A rich mid-game controller: a 御用達手前 shop with staff, discovered recipes,
/// stock, reinvestment levels and banked soul points — so every screen shows
/// real content instead of the empty first-week state. Screens only READ state,
/// so hand-seeding is deterministic and self-contained (no simulation needed).
GameController _seeded(
  Balance b, {
  bool trend = false,
  bool full = false,
  bool ended = false,
}) {
  final g = GameController(
    balance: b,
    clock: FakeTickClock(),
    seed: 7,
    entitlements: Entitlements(isFull: full),
  );
  final s = g.state;
  s.week = 880; // ~17年目あたり
  s.funds = 128400;
  s.fame = 6200;
  s.rank = 3;
  s.employees = 7;
  s.equipmentLevel = 6;
  s.qualityStar = 3;
  s.productionBonusX100 = 0;
  s.totalRevenue = 3450000;
  s.inventions = 3;
  // Discover the first dozen band-1 staples and give them stock.
  var d = 0;
  for (final r in b.recipes) {
    if (d >= 12) break;
    if (r.band == 1) {
      s.discovered[r.id] = true;
      s.productStock[r.id] = 4 + (r.id % 7);
      d++;
    }
  }
  s.discoveries = d;
  for (var i = 0; i < s.materialStock.length; i++) {
    s.materialStock[i] = 8 + (i % 5) * 3;
  }
  // Banked soul memory + a few owned nodes for the 魂の記憶 tree.
  g.meta.soulPoints = 180;
  for (final u in b.unlocks) {
    if ((u.tier == 'free' || u.tier == 'auto') && u.id < 3) {
      g.meta.unlockLevels[u.id] = 1;
    }
  }
  if (trend) {
    s.trendCategory = 0; // 食品
    s.trendForecastWeeks = 0;
    s.trendActiveWeeks = 6;
    s.trendMultX100 = 260;
  }
  g.lifeNumber = 3;
  if (ended) {
    // retire() computes the lifetime score, then relabel as a natural 寿命 end.
    g.retire();
    s.endReason = 'lifespan';
  }
  return g;
}

Widget _framed(GameController game, Widget child) => ProviderScope(
  overrides: [
    balanceProvider.overrideWith((ref) => Future.value(game.balance)),
    tickClockProvider.overrideWithValue(FakeTickClock()),
    saveStoreProvider.overrideWith((ref) async => null),
    gameControllerProvider.overrideWith((ref) => game),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme().copyWith(
      textTheme: buildTheme().textTheme.apply(
        fontFamily: 'Hiragino',
        fontFamilyFallback: const ['AppleColorEmoji'],
      ),
    ),
    home: child,
  ),
);

/// Sets an iPhone-ish canvas for one test and tears it down.
void _canvas(WidgetTester tester) {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    GameController game,
    Widget screen,
    String name,
  ) async {
    _canvas(tester);
    await tester.pumpWidget(_framed(game, screen));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/scene_$name.png'),
    );
  }

  testWidgets('scene: タイトル', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket()),
      TitleScreen(onStart: () {}, onFull: () {}, hasProgress: false),
      'title',
    );
  });

  testWidgets('scene: 遊び方', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket()),
      const HowToPlayScreen(),
      'how_to_play',
    );
  });

  testWidgets('scene: メイン画面（初回ガイド）', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    final fresh = GameController(
      balance: loadTestBalanceMarket(),
      clock: FakeTickClock(),
      seed: 7,
    );
    await shot(tester, fresh, const MainScreen(), 'main_welcome');
  });

  testWidgets('scene: メイン画面（中盤）', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket()),
      const MainScreen(),
      'main',
    );
  });

  testWidgets('scene: メイン画面（流行中バー）', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket(), trend: true),
      const MainScreen(),
      'main_trend',
    );
  });

  testWidgets('scene: PB開発', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket()),
      const DevelopScreen(),
      'develop',
    );
  });

  testWidgets('scene: 生産・再投資', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket()),
      const ProductionScreen(),
      'production',
    );
  });

  testWidgets('scene: 販売', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket()),
      const SalesScreen(),
      'sales',
    );
  });

  testWidgets('scene: 発注', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket()),
      const OrderScreen(),
      'order',
    );
  });

  testWidgets('scene: 魂の記憶ツリー', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket()),
      const SoulMemoryScreen(),
      'soul_memory',
    );
  });

  testWidgets('scene: 設定', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket()),
      const SettingsScreen(),
      'settings',
    );
  });

  testWidgets('scene: 完全版ペイウォール', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    _canvas(tester);
    final game = _seeded(loadTestBalanceMarket());
    await tester.pumpWidget(_framed(game, const SettingsScreen()));
    await tester.pumpAndSettle();
    // Open the paywall bottom sheet from Settings（§14.4 の入口の一つ）.
    await tester.tap(find.text('見る'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/scene_paywall.png'),
    );
  });

  testWidgets('scene: 人生終了・転生', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    await shot(
      tester,
      _seeded(loadTestBalanceMarket(), ended: true),
      const MainScreen(),
      'life_end',
    );
  });

  // --- Loop "moments": the emotional beats (§12.5 / §13 / §3.7). Rendered
  // stand-alone (no controller needed) over the shop backdrop. ---

  testWidgets('scene: オンボーディング（転生カットイン）', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    _canvas(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme().copyWith(
          textTheme: buildTheme().textTheme.apply(
            fontFamily: 'Hiragino',
            fontFamilyFallback: const ['AppleColorEmoji'],
            bodyColor: const Color(0xFFFFFFFF),
            displayColor: const Color(0xFFFFFFFF),
          ),
        ),
        home: OnboardingFlow(onDone: () {}),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(OnboardingFlow),
      matchesGoldenFile('goldens/scene_onboarding.png'),
    );
  });

  testWidgets('scene: イベント選択', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    _canvas(tester);
    final b = loadTestBalanceMarket();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme().copyWith(
          textTheme: buildTheme().textTheme.apply(
            fontFamily: 'Hiragino',
            fontFamilyFallback: const ['AppleColorEmoji'],
          ),
        ),
        home: Stack(
          children: [
            Container(color: const Color(0xFFF3E9D2)),
            EventDialog(event: b.events[20], onChoose: (_) {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(EventDialog),
      matchesGoldenFile('goldens/scene_event.png'),
    );
  });

  testWidgets('scene: 発明演出', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadFonts();
    _canvas(tester);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme().copyWith(
          textTheme: buildTheme().textTheme.apply(
            fontFamily: 'Hiragino',
            fontFamilyFallback: const ['AppleColorEmoji'],
          ),
        ),
        home: Stack(
          children: [
            Container(color: const Color(0xFFF3E9D2)),
            InventionOverlay(
              event: const InventionEvent(0, 'プリン', 300, 30, desc: '前世ではコンビニの定番デザート。とろける甘い卵菓子を、この世界の住民はまだ知らない。'),
              onDismiss: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(
      find.byType(InventionOverlay),
      matchesGoldenFile('goldens/scene_invention.png'),
    );
  });
}
