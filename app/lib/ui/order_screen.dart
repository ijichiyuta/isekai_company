import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../game/format.dart';
import '../game/providers.dart';

/// 発注 (requirements §4, §12.2): buy materials. Reservations apply next week
/// (§2.1 予約制), but for a smoother slice we step once on confirm.
class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    final b = game.balance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('発注'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('所持 ${formatG(game.state.funds)}')),
          ),
        ],
      ),
      body: ListView(
        children: [
          for (final m in b.materials)
            ListTile(
              title: Text(m.name),
              subtitle: Text('単価 ${m.cost}G ・ 在庫 ${game.state.materialStock[m.id]}'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  for (final qty in [1, 10])
                    OutlinedButton(
                      onPressed: game.isAlive &&
                              game.state.funds >= m.cost * qty
                          ? () {
                              game.reserve(OrderMaterial(m.id, qty));
                              game.step();
                            }
                          : null,
                      child: Text('+$qty'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
