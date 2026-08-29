import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../game/game_controller.dart';
import '../game/providers.dart';
import 'background.dart';
import 'game_ui.dart';
import 'paywall.dart';
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
        appBar: pixelAppBar(title: PixelTitle(art.sparkle, '魂の記憶')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: PixelBox(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未使用ポイント: ${game.soulPointsTotal} pt',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kInkText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '解放済み ${s.owned} / ${s.total}'
                      '${s.fullLocked > 0 ? '（完全版で+${s.fullLocked}解放可）' : ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8A6A44),
                      ),
                    ),
                    if (!game.isFull && s.fullLocked > 0) ...[
                      const SizedBox(height: 12),
                      PixelButton(
                        onTap: () => showPaywall(context),
                        fill: kAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_open,
                              size: 18,
                              color: kInkText,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '完全版で ${s.unlockedByFull}項目を解放',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: kInkText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (game.isFull)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          '✔ 完全版 購入済み',
                          style: TextStyle(
                            color: Color(0xFF2F7D3A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
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
      trailing = const _Tag('自動付与', Color(0xFF5B7186));
    } else if (owned && !def.infinite) {
      trailing = const _Tag('取得済', Color(0xFF2F7D3A));
    } else if (!isUnlockFunctional(def)) {
      // Effect not shipped yet — don't let the player spend points on a no-op.
      trailing = const _Tag('今後有効化', Color(0xFFB5731E));
    } else if (fullLocked) {
      trailing = PixelButton(
        onTap: () => showPaywall(context),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock, size: 15, color: kInkText),
            SizedBox(width: 4),
            Text(
              '完全版',
              style: TextStyle(fontWeight: FontWeight.bold, color: kInkText),
            ),
          ],
        ),
      );
    } else if (!reqOk) {
      trailing = const _Tag('前提未取得', Color(0xFF8A6A44));
    } else {
      final canAfford = game.soulPointsTotal >= cost;
      trailing = PixelButton(
        onTap: canAfford
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
        fill: canAfford ? kAccent : kPanel,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          '$cost pt',
          style: const TextStyle(fontWeight: FontWeight.bold, color: kInkText),
        ),
      );
    }

    return PixelListTile(
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
  Widget build(BuildContext context) => PixelBox(
    raised: false,
    fill: const Color(0xFFF1E4C4),
    bevel: 1,
    outline: 1.5,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
    ),
  );
}
