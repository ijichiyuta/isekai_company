import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../debug/debug_menu.dart';
import '../game/format.dart';
import '../game/game_controller.dart';
import '../game/providers.dart';
import 'background.dart';
import 'develop_screen.dart';
import 'game_ui.dart';
import 'how_to_play_screen.dart';
import 'event_dialog.dart';
import 'invention_overlay.dart';
import 'order_screen.dart';
import 'paywall.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;
import 'production_screen.dart';
import 'progress.dart';
import 'sales_screen.dart';
import 'settings_screen.dart';
import 'soul_memory_screen.dart';
import 'theme.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    // The controller auto-pauses when it raises an invention (see step()), so
    // the overlay just reads the pending event here.
    final invention = game.pendingInvention;
    final event = game.pendingEvent;
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _Hud(game: game),
                _NextRankBar(game: game),
                if (game.trendCategoryName != null) _TrendBar(game: game),
                Expanded(child: _ShopView(game: game)),
                _WeeklyResult(game: game),
                _SpeedBar(game: game),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(game: game),
        ),
        // Inventions take priority; then pending events (§3.7).
        if (invention != null)
          InventionOverlay(
            event: invention,
            onDismiss: game.acknowledgeInvention,
          )
        else if (event != null && game.isAlive)
          EventDialog(event: event, onChoose: game.chooseEvent),
        if (!game.isAlive) _LifeEndBanner(game: game),
      ],
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final s = game.state;
    final cal = calendar(s.week);
    final rank = game.balance.ranks[s.rank];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFECDBB0), Color(0xFFDDC88F)],
        ),
        border: Border(bottom: BorderSide(color: kInk, width: 2)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      child: Row(
        children: [
          // The HUD stays compact (coin icon + "資金" already say ゴールド);
          // the ゴールド unit is spelled out in the roomier price/cost contexts.
          _stat(art.coin, formatG(s.funds), '資金'),
          const SizedBox(width: 8),
          _stat(art.star, '${s.fame}', '名声'),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rank.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: kInkText,
                ),
              ),
              Text(
                '${cal.year}年 ${seasonNames[cal.season]} ${cal.weekOfSeason}週',
                style: const TextStyle(fontSize: 12, color: kInkText),
              ),
            ],
          ),
          const SizedBox(width: 8),
          PixelButton(
            semanticLabel: '設定',
            padding: const EdgeInsets.all(6),
            onTap: () {
              game.pauseForScreen();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            child: PixelView(art.gear, height: 20),
          ),
        ],
      ),
    );
  }

  // A sunken "readout" plate — icon + value, like a little status window.
  Widget _stat(PixelSprite sprite, String value, String label) => Semantics(
    label: label,
    value: value,
    child: PixelBox(
      raised: false,
      fill: const Color(0xFFF6EBCB),
      bevel: 1.5,
      outline: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelView(sprite, height: 18),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: kInkText,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Season/trend indicator (§7): forecast (予告) then live (流行中). Prompts the
/// player to produce the trending category and capture the ×2-3 demand.
class _TrendBar extends StatelessWidget {
  const _TrendBar({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final active = game.trendActive;
    final key = game.trendCategoryName!;
    final cat = categoryJa(key);
    final weeks = game.trendWeeksLeft;
    final mult = (game.trendMultPercent / 100).toStringAsFixed(1);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: active
              ? const [Color(0xFFF6C97A), Color(0xFFEDB458)]
              : const [Color(0xFFC2E1EC), Color(0xFFA9D2E2)],
        ),
        border: const Border(
          top: BorderSide(color: kInk, width: 2),
          bottom: BorderSide(color: kInk, width: 2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Row(
        children: [
          PixelView(
            active ? art.flame : art.sparkle,
            height: 16,
            semanticLabel: active ? '流行中' : '流行予告',
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              active
                  ? '流行中: $cat（需要×$mult・あと$weeks週）'
                  : '流行予告: $cat（あと$weeks週で開始）',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kInkText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextRankBar extends StatelessWidget {
  const _NextRankBar({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final s = game.state;
    final ranks = game.balance.ranks;
    if (s.rank + 1 >= ranks.length || !ranks[s.rank + 1].enabled) {
      return const SizedBox.shrink();
    }
    final next = ranks[s.rank + 1];
    final ratio = rankUpProgress(
      funds: s.funds,
      fame: s.fame,
      minAssets: next.minAssets,
      minFame: next.minFame,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '次のランク: ${next.name}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kInkText,
            ),
          ),
          const SizedBox(height: 3),
          PixelMeter(value: ratio, height: 12),
        ],
      ),
    );
  }
}

class _ShopView extends StatelessWidget {
  const _ShopView({required this.game});
  final GameController game;

  // The fantasy folk who drop by — a townsperson, a noble lady, an old
  // gentleman, an adventurer. Rotates by week so the異世界 feels lived-in.
  static final _visitors = [
    art.villagerHd,
    art.ladyHd,
    art.elderHd,
    art.adventurerHd,
  ];
  static const _visitorLabels = ['町人', '貴婦人', '老紳士', '冒険者'];

  @override
  Widget build(BuildContext context) {
    final s = game.state;
    final vi = s.week % _visitors.length;
    // Products the shop currently has on hand — shown on the shelf so the
    // diorama reflects your real inventory (§ user request).
    final onShelf = <RecipeDef>[];
    for (final r in game.balance.recipes) {
      if (s.discovered[r.id] && s.productStock[r.id] > 0) onShelf.add(r);
      if (onShelf.length >= 6) break;
    }
    // A couple of your best-stocked materials, shown as sacks by the counter.
    final matStock = <int>[];
    for (var i = 0; i < game.balance.materials.length; i++) {
      if (s.materialStock[i] > 0) matStock.add(i);
      if (matStock.length >= 3) break;
    }
    return AppBackground(
      scenery: true,
      season: calendar(s.week).season, // 春夏秋冬で壁の色と舞い散りが変わる
      child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // scaleDown keeps the diorama crisp at native size on a phone, yet
        // never overflows a shorter/odd viewport (e.g. the 800×600 test surface).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A populated shop-room diorama (HD dot-art over a soft, non-pixel
              // lit background): back wall with windows, floor, storefront, and
              // 店主 greeting a customer with props flanking.
              Container(
                width: 356,
                height: 330,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: kInk, // hard 2px outline frame (square, retro)
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      // beveled inner edge: lit top-left, shaded bottom-right
                      border: Border(
                        top: BorderSide(color: kBevelLight, width: 3),
                        left: BorderSide(color: kBevelLight, width: 3),
                        right: BorderSide(color: kBevelShadeC, width: 3),
                        bottom: BorderSide(color: kBevelShadeC, width: 3),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Soft, lit room (non-pixel wallpaper).
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFFCF3DA),
                                  Color(0xFFF3E4BE),
                                  Color(0xFFE9D3A2),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Align(
                          alignment: Alignment(0, -0.15),
                          child: SizedBox(
                            width: 360,
                            height: 300,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0x55FFFFFF),
                                    Color(0x00FFFFFF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Floor.
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: 1,
                            heightFactor: 0.26,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFDCC08A),
                                    Color(0xFFC9AC72),
                                  ],
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: Color(0xFFB89A62),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Back-wall windows.
                        Align(
                          alignment: const Alignment(-0.62, -0.5),
                          child: PixelView(art.window, pixelSize: 2),
                        ),
                        Align(
                          alignment: const Alignment(0.62, -0.5),
                          child: PixelView(art.window, pixelSize: 2),
                        ),
                        // Storefront on the floor line.
                        Align(
                          alignment: const Alignment(0, -0.02),
                          child: PixelView(
                            art.shop,
                            pixelSize: 3,
                            semanticLabel: '自分の商店',
                          ),
                        ),
                        // Your products on the shelf (reflect real inventory).
                        if (onShelf.isNotEmpty)
                          Align(
                            alignment: const Alignment(0, -0.30),
                            child: Semantics(
                              label: '陳列中の商品',
                              child: Wrap(
                                spacing: 5,
                                children: [
                                  for (final r in onShelf)
                                    PixelView(
                                      art.categoryIcon(r.category),
                                      height: 15,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        // Your materials as sacks by the counter.
                        if (matStock.isNotEmpty)
                          Align(
                            alignment: const Alignment(-0.86, 0.30),
                            child: Semantics(
                              label: '仕入れた素材',
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final m in matStock)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: PixelView(
                                        art.materialIcon(m),
                                        height: 16,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        // 店主 greets a customer, props flanking.
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                PixelView(art.plant, pixelSize: 2),
                                const SizedBox(width: 8),
                                PixelView(
                                  art.hero,
                                  pixelSize: 2,
                                  semanticLabel: '店主',
                                ),
                                const SizedBox(width: 22),
                                PixelView(
                                  _visitors[vi],
                                  pixelSize: 2,
                                  flip: true,
                                  semanticLabel: _visitorLabels[vi],
                                ),
                                const SizedBox(width: 8),
                                PixelView(art.barrel, pixelSize: 2),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '従業員 ${s.employees}人 ・ 発見レシピ ${s.discoveries}種',
                style: const TextStyle(fontSize: 13),
              ),
              // Brand-new player (no products yet): a friendly what-to-do card.
              if (s.discoveries == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _WelcomeGuide(game: game),
                ),
              if (s.pendingHintCount(game) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _bottleneck(context, game),
                ),
            ],
          ),
        ),
      ),
        ),
    );
  }

  Widget _bottleneck(BuildContext context, GameController game) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final b in game.state.bottlenecks(game))
          PixelButton(
            fill: const Color(0xFFEFC9A0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            // §12.3: tapping a bottleneck jumps straight to the screen that
            // resolves it.
            onTap: () {
              game.pauseForScreen();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => b.screen));
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_forward, size: 14, color: kInkText),
                const SizedBox(width: 4),
                Text(
                  b.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: kInkText,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A brand-new player's what-to-do card (shown until the first product exists).
class _WelcomeGuide extends StatelessWidget {
  const _WelcomeGuide({required this.game});
  final GameController game;

  void _open(BuildContext context, Widget screen) {
    game.pauseForScreen();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return PixelBox(
      fill: const Color(0xFFFBEBBE),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ようこそ、異世界へ！',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: kInkText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'まずは下の「開発」で最初の商品を作ろう。並べれば自動で売れて、'
            'お金と名声が貯まっていくよ。',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: kInkText),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              PixelButton(
                onTap: () => _open(context, const DevelopScreen()),
                fill: kAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: const Text(
                  '開発をひらく',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kInkText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PixelButton(
                onTap: () => _open(context, const HowToPlayScreen()),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: const Text(
                  '遊び方',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: kInkText,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Last week's sales — makes the loop's "profit" node visible (§3.1). Also the
/// place a rank-up flashes.
class _WeeklyResult extends StatelessWidget {
  const _WeeklyResult({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final r = game.lastWeekRevenue;
    final chapter = calendar(game.state.week).year; // 1年＝1章 (§12.4)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: PixelBox(
              raised: false,
              fill: const Color(0xFFEDE6CF),
              bevel: 1,
              outline: 1.5,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              child: Text(
                '第$chapter章',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: kInkText,
                ),
              ),
            ),
          ),
          if (game.lastRankedUp)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PixelView(art.sparkle, height: 14),
                  const SizedBox(width: 4),
                  Text(
                    '昇格！',
                    style: TextStyle(fontWeight: FontWeight.bold, color: kGold),
                  ),
                ],
              ),
            ),
          Text(
            r > 0 ? '先週の売上 +${gold(r)}（${game.lastWeekSold}個）' : '先週の売上 —',
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SpeedBar extends StatelessWidget {
  const _SpeedBar({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final pending = game.pending.length;
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 6, top: 2),
      child: Row(
        children: [
          // Manual week advance (§2.1): applies reservations without running the
          // clock. Only useful while paused.
          if (game.speed == GameSpeed.paused)
            PixelButton(
              onTap: game.isAlive ? game.step : null,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF9AD37F), Color(0xFF66B257)],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                pending > 0 ? '次の週へ ($pending)' : '次の週へ',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C4720),
                ),
              ),
            ),
          const Spacer(),
          for (final sp in GameSpeed.values)
            // ×3 is gated behind 時の加速 (§8.4 #14) — hidden until unlocked.
            if (sp != GameSpeed.x3 || game.speedX3Unlocked)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: PixelButton(
                  onTap: game.isAlive ? () => game.setSpeed(sp) : null,
                  fill: game.speed == sp ? kAccent : kPanel,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Text(
                    sp.label,
                    style: TextStyle(
                      fontWeight: game.speed == sp
                          ? FontWeight.bold
                          : FontWeight.w600,
                      fontSize: 14,
                      color: kInkText,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.game});
  final GameController game;

  void _open(BuildContext context, Widget screen) {
    game.pauseForScreen(); // §12.1: management screens auto-pause
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    // A wooden shelf the action "keys" sit on — chunky, warm, game-like (not a
    // flat Material bottom bar).
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCBA66E), Color(0xFFB2894F)],
        ),
        border: Border(top: BorderSide(color: Color(0xFF8A5E30), width: 2)),
        boxShadow: [
          BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 7),
          child: Row(
            children: [
              _navItem(context, art.beaker, '開発', const DevelopScreen()),
              _navItem(
                context,
                art.factoryIcon,
                '生産',
                const ProductionScreen(),
              ),
              _navItem(context, art.storefront, '販売', const SalesScreen()),
              _navItem(context, art.cart, '発注', const OrderScreen()),
              if (kDebugMode)
                _navItem(context, null, 'デバッグ', const DebugMenu()),
            ],
          ),
        ),
      ),
    );
  }

  // A single square, beveled "key" (press-invert, no ripple) — reads as a
  // physical button, not a tab.
  Widget _navItem(
    BuildContext context,
    PixelSprite? sprite,
    String label,
    Widget screen,
  ) {
    final icon = sprite != null
        ? PixelView(sprite, height: 24)
        : const Icon(Icons.bug_report, size: 22, color: kInkText);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: PixelButton(
          onTap: () => _open(context, screen),
          semanticLabel: label,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8EBCB), Color(0xFFE7CF9E)],
          ),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 26, child: Center(child: icon)),
              const SizedBox(height: 1),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kInkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 人生終了・評価画面 (requirements §8.2, screen #16). Shows the lifetime score
/// breakdown and the soul points earned, then offers 転生 (rebirth).
class _LifeEndBanner extends StatelessWidget {
  const _LifeEndBanner({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final reason = switch (game.state.endReason) {
      'bankrupt' => '破産',
      'retire' => '引退',
      _ => '寿命',
    };
    final sc = game.lifeScore;
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 320,
                child: PixelBox(
                bevel: 3,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${game.lifeNumber}周目の人生が終わった（$reason）',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kInkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '到達ランク: ${game.balance.ranks[game.state.rank].name}',
                      style: const TextStyle(fontSize: 13, color: kInkText),
                    ),
                    const _InkRule(),
                    if (sc != null) ...[
                      _row('最終資産', sc.assetsPart),
                      _row('累積名声', sc.famePart),
                      _row(
                        '発見レシピ (${game.state.discoveries}種)',
                        sc.recipesPart,
                      ),
                      _row('到達ランク', sc.rankPart),
                      const _InkRule(),
                      _row('生涯スコア', sc.total, bold: true),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PixelView(art.sparkle, height: 15),
                          const SizedBox(width: 5),
                          Text(
                            '魂の記憶 +${game.pendingSoulPoints} pt',
                            style: const TextStyle(
                              color: kFame,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '（累計 ${game.soulPointsTotal + game.pendingSoulPoints} pt）',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _wideBtn(
                      Icons.auto_awesome,
                      '魂の記憶ツリー（恒久アンロック）',
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SoulMemoryScreen(),
                        ),
                      ),
                    ),
                    // Main paywall touchpoint (§14): surfaced from the 2nd life
                    // onward, and only when 完全版 isn't already owned.
                    if (!game.isFull && game.lifeNumber >= 2) ...[
                      const SizedBox(height: 8),
                      _wideBtn(
                        Icons.workspace_premium,
                        '完全版で恒久強化を全解放',
                        () => showPaywall(context),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _wideBtn(
                      Icons.autorenew,
                      '転生する（次の人生へ）',
                      game.rebirth,
                      gold: true,
                    ),
                  ],
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wideBtn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool gold = false,
  }) => SizedBox(
    width: double.infinity,
    child: PixelButton(
      onTap: onTap,
      fill: gold ? kAccent : kPanel,
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: kInkText),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: kInkText,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _row(String label, int pts, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
      color: kInkText,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('$pts pt', style: style),
        ],
      ),
    );
  }
}

/// A beveled divider rule (a dark line lit from below) — the pixel-GUI take on
/// a Material Divider.
class _InkRule extends StatelessWidget {
  const _InkRule();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 2,
          child: ColoredBox(color: kBevelShadeC),
        ),
        SizedBox(
          width: double.infinity,
          height: 1,
          child: ColoredBox(color: kBevelLight),
        ),
      ],
    ),
  );
}

/// A bottleneck hint plus the screen that resolves it (§12.3 タップで直行).
class Bottleneck {
  final String label;
  final Widget screen;
  const Bottleneck(this.label, this.screen);
}

/// Small UI-only helpers on GameState (kept here, not in the pure core).
extension on GameState {
  int pendingHintCount(GameController game) => bottlenecks(game).length;

  List<Bottleneck> bottlenecks(GameController game) {
    final out = <Bottleneck>[];
    final hasStock = productStock.any((q) => q > 0);
    final hasMaterials = materialStock.any((q) => q > 0);
    if (discoveries == 0) {
      out.add(const Bottleneck('レシピ未発見', DevelopScreen()));
    }
    if (!hasStock && discoveries > 0) {
      out.add(const Bottleneck('在庫なし', ProductionScreen()));
    }
    if (!hasMaterials && funds < 20) {
      out.add(const Bottleneck('資金・素材不足', OrderScreen()));
    }
    return out;
  }
}
