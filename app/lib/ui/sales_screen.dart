import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/format.dart';
import '../game/providers.dart';
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
    return Scaffold(
      appBar: AppBar(title: const PixelTitle(art.storefront, '販売')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('累計売上 ${formatG(game.state.totalRevenue)}'),
                const Text('自動販売中', style: TextStyle(color: Colors.green)),
              ],
            ),
          ),
          Expanded(
            child: known.isEmpty
                ? const Center(child: Text('販売できる商品がまだありません'))
                : ListView(
                    children: [
                      for (final r in known)
                        ListTile(
                          dense: true,
                          title: Text(r.name),
                          subtitle: Text('売値 ${r.basePrice}G'),
                          trailing: Text('在庫 ${game.state.productStock[r.id]}'),
                        ),
                    ],
                  ),
          ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '※ 販売は自動。手動値付け・棚割りは今後のアップデートで追加予定',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
