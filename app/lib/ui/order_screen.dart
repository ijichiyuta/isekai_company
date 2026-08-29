import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../game/format.dart';
import '../game/providers.dart';
import 'background.dart';
import 'game_ui.dart';
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
        appBar: pixelAppBar(
          title: PixelTitle(art.cart, '発注'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: PixelBox(
                  raised: false,
                  fill: const Color(0xFFF6EBCB),
                  bevel: 1.5,
                  outline: 1.5,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PixelView(art.coin, height: 16, semanticLabel: '資金'),
                      const SizedBox(width: 4),
                      Text(
                        gold(game.state.funds),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kInkText,
                        ),
                      ),
                    ],
                  ),
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final m in b.materials)
                    PixelListTile(
                      leading: PixelView(
                        art.materialIcon(m.id),
                        height: 30,
                        semanticLabel: m.name,
                      ),
                      title: Text(m.name),
                      subtitle: Text(
                        '単価 ${gold(m.cost)} ・ 在庫 ${game.state.materialStock[m.id]}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final qty in [1, 10])
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: PixelButton(
                                onTap: game.isAlive
                                    ? () =>
                                          game.reserve(OrderMaterial(m.id, qty))
                                    : null,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                child: Text(
                                  '+$qty',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: kInkText,
                                  ),
                                ),
                              ),
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
        padding: EdgeInsets.all(10),
        child: Text(
          'タップで来週の予約を積みます',
          style: TextStyle(fontSize: 12, color: kInkText),
        ),
      );
    }
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFF3D9A9),
        border: Border(bottom: BorderSide(color: kInk, width: 2)),
      ),
      padding: const EdgeInsets.all(8),
      child: Text(
        '来週の予約: $n 件（メイン画面で週を進めると反映）',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: kInkText,
        ),
      ),
    );
  }
}
