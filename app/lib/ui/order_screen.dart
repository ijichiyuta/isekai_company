import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../game/format.dart';
import '../game/providers.dart';
import 'background.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;

/// 発注 (requirements §4, §12.2): buy materials. Pure 予約制 (§2.1) — orders are
/// reserved and applied when the week advances (main screen), not immediately.
class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    final b = game.balance;
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: PixelTitle(art.cart, '発注'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PixelView(art.coin, height: 16),
                    const SizedBox(width: 4),
                    Text(formatG(game.state.funds)),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            const _ReservationBanner(),
            Expanded(
              child: ListView(
                children: [
                  for (final m in b.materials)
                    ListTile(
                      title: Text(m.name),
                      subtitle: Text(
                        '単価 ${m.cost}G ・ 在庫 ${game.state.materialStock[m.id]}',
                      ),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          for (final qty in [1, 10])
                            OutlinedButton(
                              onPressed: game.isAlive
                                  ? () => game.reserve(OrderMaterial(m.id, qty))
                                  : null,
                              child: Text('+$qty'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows how many commands are queued for next week (予約制 feedback).
class _ReservationBanner extends ConsumerWidget {
  const _ReservationBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(gameControllerProvider).pending.length;
    if (n == 0) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('タップで来週の予約を積みます', style: TextStyle(fontSize: 12)),
      );
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFFEFC9A0),
      padding: const EdgeInsets.all(8),
      child: Text(
        '来週の予約: $n 件（メイン画面で週を進めると反映）',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
