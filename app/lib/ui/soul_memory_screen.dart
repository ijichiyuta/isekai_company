import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../game/game_controller.dart';
import '../game/providers.dart';
import 'paywall.dart';
import 'background.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;

/// 魂の記憶ツリー画面 (§8.4). Spend soul points on permanent unlocks; 完全版
/// (full-tier) nodes show a lock and route to the paywall. Doubles as the shop
/// (完全版 purchase + 復元 live here and in Settings — §14.4 two locations).
class SoulMemoryScreen extends ConsumerWidget {
  const SoulMemoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    final s = game.unlockSummary;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: PixelTitle(art.sparkle, '魂の記憶')),
        body: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未使用ポイント: ${game.soulPointsTotal} pt',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '解放済み ${s.owned} / ${s.total}'
                      '${s.fullLocked > 0 ? '（完全版で+${s.fullLocked}解放可）' : ''}',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    if (!game.isFull && s.fullLocked > 0) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => showPaywall(context),
                        icon: const Icon(Icons.lock_open),
                        label: Text('完全版で ${s.unlockedByFull}項目を解放'),
                      ),
                    ],
                    if (game.isFull)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '✔ 完全版 購入済み',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: game.balance.unlocks.length,
                itemBuilder: (c, i) =>
                    _UnlockTile(game: game, def: game.balance.unlocks[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnlockTile extends StatelessWidget {
  const _UnlockTile({required this.game, required this.def});
  final GameController game;
  final UnlockDef def;

  @override
  Widget build(BuildContext context) {
    final level = game.meta.levelOf(def.id);
    final owned = level >= 1;
    final reqOk = def.requires.every(game.meta.isUnlocked);
    final cost = unlockCostForLevel(def, level);
    final fullLocked = def.tier == 'full' && !game.isFull;
    final auto = def.tier == 'auto';

    Widget trailing;
    if (auto && owned) {
      trailing = const _Tag('自動付与', Colors.blueGrey);
    } else if (owned && !def.infinite) {
      trailing = const _Tag('取得済', Colors.green);
    } else if (!isUnlockFunctional(def)) {
      // Effect not shipped yet — don't let the player spend points on a no-op.
      trailing = const _Tag('今後有効化', Colors.orange);
    } else if (fullLocked) {
      trailing = TextButton.icon(
        onPressed: () => showPaywall(context),
        icon: const Icon(Icons.lock, size: 16),
        label: const Text('完全版'),
      );
    } else if (!reqOk) {
      trailing = const _Tag('前提未取得', Colors.grey);
    } else {
      final canAfford = game.soulPointsTotal >= cost;
      trailing = FilledButton(
        onPressed: canAfford
            ? () {
                if (!game.purchaseUnlock(def.id)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('購入できません'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              }
            : null,
        child: Text('$cost pt'),
      );
    }

    return ListTile(
      dense: true,
      title: Text(def.infinite && owned ? '${def.name}（Lv$level）' : def.name),
      subtitle: Text(def.desc),
      trailing: trailing,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, color: color)),
  );
}
