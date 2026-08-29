import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/providers.dart';
import 'background.dart';
import 'game_ui.dart';
import 'paywall.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;
import 'soul_memory_screen.dart';

/// Settings / info screen. Hosts the SECOND 復元購入 entry point (§14.4 requires
/// restore in the shop AND settings; App Store 3.1.1) plus the 完全版 状態 and a
/// link into the 魂の記憶 tree.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    final audio = ref.watch(audioControllerProvider);
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: pixelAppBar(title: PixelTitle(art.gear, '設定')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            PixelListTile(
              leading: PixelView(art.sparkle, height: 26),
              title: const Text('魂の記憶'),
              subtitle: Text('未使用 ${game.soulPointsTotal} pt'),
              trailing: const Icon(Icons.chevron_right, color: kInkText),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SoulMemoryScreen()),
              ),
            ),
            PixelListTile(
              leading: Icon(
                game.isFull ? Icons.verified : Icons.workspace_premium,
                color: kInkText,
              ),
              title: Text(game.isFull ? '完全版 購入済み' : '完全版'),
              subtitle: Text(game.isFull ? 'すべての機能が利用できます' : '完全版でフル機能を解放'),
              trailing: game.isFull
                  ? null
                  : PixelButton(
                      onTap: () => showPaywall(context),
                      fill: kAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: const Text(
                        '見る',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kInkText,
                        ),
                      ),
                    ),
            ),
            // Restore is ALWAYS visible (App Store 3.1.1) — even when purchased.
            PixelListTile(
              leading: const Icon(Icons.restore, color: kInkText),
              title: const Text('購入を復元'),
              onTap: () async {
                final ok = await game.restorePurchases();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(ok ? '購入を復元しました' : '復元できる購入がありません')),
                  );
                }
              },
            ),
            PixelListTile(
              leading: Icon(
                audio.bgmEnabled ? Icons.music_note : Icons.music_off,
                color: kInkText,
              ),
              title: const Text('音楽 (BGM)'),
              trailing: _Toggle(
                on: audio.bgmEnabled,
                onTap: () => audio.setBgmEnabled(!audio.bgmEnabled),
              ),
            ),
            PixelListTile(
              leading: Icon(
                audio.sfxEnabled ? Icons.volume_up : Icons.volume_off,
                color: kInkText,
              ),
              title: const Text('効果音'),
              trailing: _Toggle(
                on: audio.sfxEnabled,
                onTap: () => audio.setSfxEnabled(!audio.sfxEnabled),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A chunky ON/OFF pixel toggle (gold when on) — no Material Switch.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => PixelButton(
    onTap: onTap,
    fill: on ? kAccent : kPanel,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    child: Text(
      on ? 'オン' : 'オフ',
      style: const TextStyle(fontWeight: FontWeight.bold, color: kInkText),
    ),
  );
}
