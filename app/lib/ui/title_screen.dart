import 'package:flutter/material.dart';

import 'background.dart';
import 'game_ui.dart';
import 'how_to_play_screen.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;

/// タイトル画面 (§12.2 #1) — the world-establishing first impression: the
/// isekai one-liner, the shop, はじめる/つづき, and the single 完全版 banner.
class TitleScreen extends StatelessWidget {
  const TitleScreen({
    super.key,
    required this.onStart,
    required this.onFull,
    required this.hasProgress,
  });

  final VoidCallback onStart;
  final VoidCallback onFull;
  final bool hasProgress;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      mood: BgMood.dusk,
      scenery: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Title plaque.
                  PixelBox(
                    fill: const Color(0xFFF6E8C6),
                    bevel: 3,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    child: Column(
                      children: const [
                        Text(
                          '異世界カンパニー',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: kInkText,
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '前世の知識で、異世界の経済を塗り替えろ。',
                          style: TextStyle(fontSize: 12.5, color: Color(0xFF7A5A2E)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  // Hero art — the fantasy merchant shop.
                  PixelView(art.shop, pixelSize: 3),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 240,
                    child: PixelButton(
                      onTap: onStart,
                      fill: kAccent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Center(
                        child: Text(
                          hasProgress ? 'つづきから' : 'はじめる',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: kInkText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // The single 完全版 banner (§12.2 #1: バナー1箇所のみ).
                  SizedBox(
                    width: 240,
                    child: PixelButton(
                      onTap: onFull,
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: const Center(
                        child: Text(
                          '完全版を見る',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: kInkText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HowToPlayScreen(),
                      ),
                    ),
                    child: const Text(
                      '遊び方を見る',
                      style: TextStyle(color: Color(0xFFE8D6A8)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
