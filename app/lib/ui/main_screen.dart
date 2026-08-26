import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../debug/debug_menu.dart';
import '../game/format.dart';
import '../game/game_controller.dart';
import '../game/providers.dart';
import 'develop_screen.dart';
import 'invention_overlay.dart';
import 'order_screen.dart';
import 'production_screen.dart';
import 'sales_screen.dart';
import 'theme.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    // The controller auto-pauses when it raises an invention (see step()), so
    // the overlay just reads the pending event here.
    final invention = game.pendingInvention;
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _Hud(game: game),
                _NextRankBar(game: game),
                Expanded(child: _ShopView(game: game)),
                _SpeedBar(game: game),
              ],
            ),
          ),
          bottomNavigationBar: _BottomNav(game: game),
        ),
        if (invention != null)
          InventionOverlay(
            event: invention,
            onDismiss: game.acknowledgeInvention,
          ),
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
          _stat(Icons.savings, formatG(s.funds), kGold),
          const SizedBox(width: 16),
          _stat(Icons.star, '${s.fame}', kFame),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(rank.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${cal.year}年 ${seasonNames[cal.season]} ${cal.weekOfSeason}週',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String value, Color color) => Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      );
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
    final assetsRatio =
        next.minAssets == 0 ? 1.0 : (s.funds / next.minAssets).clamp(0.0, 1.0);
    final fameRatio =
        next.minFame == 0 ? 1.0 : (s.fame / next.minFame).clamp(0.0, 1.0);
    final ratio = assetsRatio < fameRatio ? assetsRatio : fameRatio;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('次のランク: ${next.name}',
              style: const TextStyle(fontSize: 12)),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🏪', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 8),
          Text('従業員 ${s.employees}人 ・ 発見レシピ ${s.discoveries}種',
              style: const TextStyle(fontSize: 13)),
          if (s.pendingHintCount(game) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _bottleneck(context, game),
            ),
        ],
      ),
    );
  }

  Widget _bottleneck(BuildContext context, GameController game) {
    return Wrap(
      spacing: 8,
      children: [
        for (final b in game.state.bottlenecks(game))
          Chip(
            label: Text(b, style: const TextStyle(fontSize: 11)),
            backgroundColor: const Color(0xFFEFC9A0),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}

class _SpeedBar extends StatelessWidget {
  const _SpeedBar({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, bottom: 6, top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (final sp in GameSpeed.values)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ChoiceChip(
                label: Text(sp.label),
                selected: game.speed == sp,
                onSelected:
                    game.isAlive ? (_) => game.setSpeed(sp) : null,
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
          _navItem(context, Icons.science, '開発', const DevelopScreen()),
          _navItem(context, Icons.factory, '生産', const ProductionScreen()),
          _navItem(context, Icons.storefront, '販売', const SalesScreen()),
          _navItem(context, Icons.shopping_cart, '発注', const OrderScreen()),
          if (kDebugMode)
            _navItem(context, Icons.bug_report, 'デバッグ', const DebugMenu()),
        ],
      ),
    );
  }

  Widget _navItem(
      BuildContext context, IconData icon, String label, Widget screen) {
    return Expanded(
      child: InkWell(
        onTap: () => _open(context, screen),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _LifeEndBanner extends StatelessWidget {
  const _LifeEndBanner({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) {
    final reason = game.state.endReason == 'bankrupt' ? '破産' : '寿命';
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('人生終了（$reason）',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('到達ランク: ${game.balance.ranks[game.state.rank].name}'),
                  Text('発見レシピ: ${game.state.discoveries}種'),
                  const SizedBox(height: 4),
                  const Text('（転生システムは M3 で実装）',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small UI-only helpers on GameState (kept here, not in the pure core).
extension on GameState {
  int pendingHintCount(GameController game) => bottlenecks(game).length;

  List<String> bottlenecks(GameController game) {
    final out = <String>[];
    final hasStock = productStock.any((q) => q > 0);
    final hasMaterials = materialStock.any((q) => q > 0);
    if (discoveries == 0) out.add('レシピ未発見');
    if (!hasStock && discoveries > 0) out.add('在庫なし');
    if (!hasMaterials && funds < 20) out.add('資金・素材不足');
    return out;
  }
}
