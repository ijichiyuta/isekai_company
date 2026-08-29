import 'package:flutter/material.dart';

import '../game/format.dart';
import '../game/game_controller.dart';
import 'game_ui.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;

/// 発明演出 (requirements §12.5): the emotional peak. Flash → product reveal →
/// residents' astonishment → fame gained. Kept "short video friendly". A reduced
/// (no-flash) variant will honor the accessibility setting in §12.6 later.
class InventionOverlay extends StatefulWidget {
  const InventionOverlay({
    super.key,
    required this.event,
    required this.onDismiss,
  });
  final InventionEvent event;
  final VoidCallback onDismiss;

  @override
  State<InventionOverlay> createState() => _InventionOverlayState();
}

class _InventionOverlayState extends State<InventionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

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
          color: Colors.black.withValues(alpha: 0.72),
          child: Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
              child: PixelBox(
                fill: const Color(0xFFFFF7E0),
                bevel: 3,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 32,
                ),
                child: Builder(
                  builder: (context) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PixelView(art.sparkle, height: 15),
                          const SizedBox(width: 6),
                          const Text(
                            '異世界初',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFFC8991F),
                            ),
                          ),
                          const SizedBox(width: 6),
                          PixelView(art.sparkle, height: 15),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '「${widget.event.name}」を発明！',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '街の人々が驚いている……！',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _bonus(art.coin, '+${formatG(widget.event.cashBonus)}G'),
                          _bonus(art.star, '+${widget.event.fameBonus} 名声'),
                        ],
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
      ),
    );
  }

  Widget _bonus(PixelSprite sprite, String text) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      PixelView(sprite, height: 18),
      const SizedBox(width: 5),
      Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, color: kInkText),
      ),
    ],
  );
}
