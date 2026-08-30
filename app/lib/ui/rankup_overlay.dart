import 'package:flutter/material.dart';

import '../game/audio/audio_controller.dart';
import '../game/audio/chiptune.dart';
import '../game/game_controller.dart';
import 'game_ui.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;

/// 昇格演出 (requirements §12.5): the first-layer milestone celebration. Flash →
/// the shop visibly GROWS (art.shopForRank renders bigger per rank) → the new
/// rank title. Reuses the invention overlay's elastic beat so the loop's two
/// peaks (発明 / 昇格) feel like siblings. A little fanfare (Sfx.rankUp).
class RankUpOverlay extends StatefulWidget {
  const RankUpOverlay({
    super.key,
    required this.event,
    required this.onDismiss,
  });
  final RankUpEvent event;
  final VoidCallback onDismiss;

  @override
  State<RankUpOverlay> createState() => _RankUpOverlayState();
}

class _RankUpOverlayState extends State<RankUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    playSfxHook(Sfx.rankUp); // the §12.5 milestone fanfare
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.74),
          child: Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
              child: PixelBox(
                fill: const Color(0xFFFFF7E0),
                bevel: 3,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 30,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PixelView(art.sparkle, height: 15),
                        const SizedBox(width: 6),
                        const Text(
                          '商会が大きくなった',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFC8991F),
                          ),
                        ),
                        const SizedBox(width: 6),
                        PixelView(art.sparkle, height: 15),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // The shop that just grew — the visible payoff of ranking up.
                    PixelView(art.shopForRank(widget.event.rank), height: 96),
                    const SizedBox(height: 14),
                    Text(
                      '「${widget.event.rankName}」に昇格！',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: kInkText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PixelButton(
                      onTap: widget.onDismiss,
                      fill: kAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      child: const Text(
                        'タップして続ける',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kInkText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
