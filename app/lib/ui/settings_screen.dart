import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/providers.dart';
import 'paywall.dart';
import 'soul_memory_screen.dart';

/// Settings / info screen. Hosts the SECOND 復元購入 entry point (§14.4 requires
/// restore in the shop AND settings; App Store 3.1.1) plus the 完全版 状態 and a
/// link into the 魂の記憶 tree.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('魂の記憶'),
            subtitle: Text('未使用 ${game.soulPointsTotal} pt'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const SoulMemoryScreen())),
          ),
          const Divider(),
          ListTile(
            leading: Icon(game.isFull ? Icons.verified : Icons.workspace_premium),
            title: Text(game.isFull ? '完全版 購入済み' : '完全版'),
            subtitle: Text(game.isFull ? 'すべての機能が利用できます' : '完全版でフル機能を解放'),
            trailing: game.isFull
                ? null
                : TextButton(
                    onPressed: () => showPaywall(context),
                    child: const Text('見る'),
                  ),
          ),
          // Restore is ALWAYS visible (App Store 3.1.1) — even when purchased.
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('購入を復元'),
            onTap: () async {
              final ok = await game.restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? '購入を復元しました' : '復元できる購入がありません')));
              }
            },
          ),
        ],
      ),
    );
  }
}
