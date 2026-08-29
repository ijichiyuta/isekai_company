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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFE7D6AE),
      child: Row(
        children: [
          _stat(art.coin, formatG(s.funds), '資金'),
          const SizedBox(width: 16),
          _stat(art.star, '${s.fame}', '名声'),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                rank.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                '${cal.year}年 ${seasonNames[cal.season]} ${cal.weekOfSeason}週',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          IconButton(
            icon: PixelView(art.gear, height: 20, semanticLabel: '設定'),
            tooltip: '設定',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              game.pauseForScreen();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _stat(PixelSprite sprite, String value, String label) => Semantics(
    label: label,
    value: value,
    child: Row(
      children: [
        PixelView(sprite, height: 20),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
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
      color: active ? const Color(0xFFFFE0B2) : const Color(0xFFE1F5FE),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('次のランク: ${next.name}', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: ratio, minHeight: 8),
          ),
        ],
      ),
    );
  }
}

class _ShopView extends StatelessWidget {
  const _ShopView({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final s = game.state;
    return AppBackground(
      scenery: true,
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
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 18,
                      offset: Offset(0, 9),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFCBB488),
                        width: 2,
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
                            semanticLabel: '異世界コンビニ商会',
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
                                  art.customer,
                                  pixelSize: 2,
                                  flip: true,
                                  semanticLabel: '客',
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
      children: [
        for (final b in game.state.bottlenecks(game))
          ActionChip(
            label: Text(b.label, style: const TextStyle(fontSize: 11)),
            backgroundColor: const Color(0xFFEFC9A0),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(Icons.arrow_forward, size: 14),
            // §12.3: tapping a bottleneck jumps straight to the screen that
            // resolves it.
            onPressed: () {
              game.pauseForScreen();
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => b.screen));
            },
          ),
      ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
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
            r > 0 ? '先週の売上 +${formatG(r)}（${game.lastWeekSold}個）' : '先週の売上 —',
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
            FilledButton.tonal(
              onPressed: game.isAlive ? game.step : null,
              child: Text(pending > 0 ? '次の週へ ($pending)' : '次の週へ'),
            ),
          const Spacer(),
          for (final sp in GameSpeed.values)
            // ×3 is gated behind 時の加速 (§8.4 #14) — hidden until unlocked.
            if (sp != GameSpeed.x3 || game.speedX3Unlocked)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: ChoiceChip(
                  label: Text(sp.label),
                  selected: game.speed == sp,
                  onSelected: game.isAlive ? (_) => game.setSpeed(sp) : null,
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
    return BottomAppBar(
      height: 64,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _navItem(
            context,
            PixelView(art.beaker, height: 24),
            '開発',
            const DevelopScreen(),
          ),
          _navItem(
            context,
            PixelView(art.factoryIcon, height: 24),
            '生産',
            const ProductionScreen(),
          ),
          _navItem(
            context,
            PixelView(art.storefront, height: 24),
            '販売',
            const SalesScreen(),
          ),
          _navItem(
            context,
            PixelView(art.cart, height: 24),
            '発注',
            const OrderScreen(),
          ),
          if (kDebugMode)
            _navItem(
              context,
              const Icon(Icons.bug_report, size: 22),
              'デバッグ',
              const DebugMenu(),
            ),
        ],
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    Widget icon,
    String label,
    Widget screen,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => _open(context, screen),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 26, child: Center(child: icon)),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
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
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${game.lifeNumber}周目の人生が終わった（$reason）',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '到達ランク: ${game.balance.ranks[game.state.rank].name}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const Divider(height: 24),
                    if (sc != null) ...[
                      _row('最終資産', sc.assetsPart),
                      _row('累積名声', sc.famePart),
                      _row(
                        '発見レシピ (${game.state.discoveries}種)',
                        sc.recipesPart,
                      ),
                      _row('到達ランク', sc.rankPart),
                      const Divider(height: 16),
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
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SoulMemoryScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('魂の記憶ツリー（恒久アンロック）'),
                    ),
                    // Main paywall touchpoint (§14): surfaced from the 2nd life
                    // onward, and only when 完全版 isn't already owned.
                    if (!game.isFull && game.lifeNumber >= 2) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => showPaywall(context),
                        icon: const Icon(Icons.workspace_premium, size: 18),
                        label: const Text('完全版で恒久強化を全解放'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: game.rebirth,
                      icon: const Icon(Icons.autorenew),
                      label: const Text('転生する（次の人生へ）'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, int pts, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 16 : 14,
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
