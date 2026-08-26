import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/format.dart';
import '../game/providers.dart';

/// Debug menu (requirements §10.6). Reached only behind `if (kDebugMode)` in the
/// nav, so the const-false kDebugMode in release builds makes this dead code and
/// it is tree-shaken out — satisfying AC-14 (no debug menu in production).
class DebugMenu extends ConsumerWidget {
  const DebugMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    assert(kDebugMode, 'DebugMenu must never be reachable in release');
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('デバッグ')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('week ${game.state.week} / funds ${formatG(game.state.funds)} '
              '/ fame ${game.state.fame} / rank ${game.state.rank}'),
          const Divider(),
          _btn('資金 +10,000G', () => game.debugGrant(10000)),
          _btn('資金 +1,000,000G', () => game.debugGrant(1000000)),
          _btn('1週 進める', () => game.debugStep()),
          _btn('12週 進める', () => game.debugStep(12)),
          _btn('全レシピ発見', () {
            for (final r in game.balance.recipes) {
              game.state.discovered[r.id] = true;
            }
            game.debugStep();
          }),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: FilledButton.tonal(onPressed: onTap, child: Text(label)),
      );
}
