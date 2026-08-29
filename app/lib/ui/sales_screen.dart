import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/format.dart';
import '../game/providers.dart';
import 'background.dart';
import 'game_ui.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;

/// 販売・棚割り (requirements §4, §12.2). Sales happen automatically each week
/// (the engine sells stock into the shared demand pool). Manual pricing/棚割り
/// is M2; for now this screen surfaces stock and cumulative revenue.
class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    final b = game.balance;
    final known = [
      for (final r in b.recipes)
        if (game.state.discovered[r.id]) r,
    ];
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: pixelAppBar(title: PixelTitle(art.storefront, '販売')),
        body: Column(
          children: [
            maeseMemo('前世の記憶　「棚割り」＝並べれば自動で売れる。売れ筋を切らさぬよう在庫を保て。'),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '累計売上 ${gold(game.state.totalRevenue)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kInkText,
                    ),
                  ),
                  const Text(
                    '自動販売中',
                    style: TextStyle(
                      color: Color(0xFF2F7D3A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: known.isEmpty
                  ? const Center(
                      child: Text(
                        '販売できる商品がまだありません',
                        style: TextStyle(color: kInkText),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 8),
                      children: [
                        for (final r in known)
                          PixelListTile(
                            leading: PixelView(
                              art.categoryIcon(r.category),
                              height: 28,
                              semanticLabel: categoryJa(r.category),
                            ),
                            title: Text(r.name),
                            subtitle: Text('売値 ${gold(r.basePrice)}'),
                            trailing: PixelBox(
                              raised: false,
                              fill: const Color(0xFFF6EBCB),
                              bevel: 1.5,
                              outline: 1.5,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                '在庫 ${game.state.productStock[r.id]}',
                                style: const TextStyle(
                                  color: kInkText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                '※ 販売は自動。手動値付け・棚割りは今後のアップデートで追加予定',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A6A44)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
