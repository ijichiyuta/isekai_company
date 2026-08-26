import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../game/providers.dart';

/// 生産 (requirements §4, §12.2): produce discovered recipes from materials.
/// Capacity = base + employees × output; the engine clamps to stock/capacity.
class ProductionScreen extends ConsumerWidget {
  const ProductionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    final b = game.balance;
    final eco = b.economy;
    final capacity =
        eco.baseCapacityPerWeek + game.state.employees * eco.artisanOutputPerWeek;
    final known = [
      for (final r in b.recipes)
        if (game.state.discovered[r.id]) r
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('生産')),
      body: known.isEmpty
          ? const Center(child: Text('まずPB開発でレシピを発見しましょう'))
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('週あたり生産能力: $capacity 個'
                      '（従業員 ${game.state.employees}人）'),
                ),
                for (final r in known)
                  ListTile(
                    title: Text(r.name),
                    subtitle: Text('完成品在庫 ${game.state.productStock[r.id]} '
                        '・ 素材 ${b.materials[r.matA].name}/${b.materials[r.matB].name}'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        for (final qty in [1, 5])
                          OutlinedButton(
                            // Reserve the needed materials too, so production
                            // succeeds regardless of order (§2.1 予約制; applied
                            // when the week advances).
                            onPressed: game.isAlive
                                ? () {
                                    if (r.matA == r.matB) {
                                      game.reserve(OrderMaterial(r.matA, qty * 2));
                                    } else {
                                      game.reserve(OrderMaterial(r.matA, qty));
                                      game.reserve(OrderMaterial(r.matB, qty));
                                    }
                                    game.reserve(Produce(r.id, qty));
                                  }
                                : null,
                            child: Text('作+$qty'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
