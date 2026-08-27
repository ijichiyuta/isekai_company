import 'package:flutter/material.dart';

import '../game/game_controller.dart';
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
              child: Card(
                color: const Color(0xFFFFF7E0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          PixelView(art.sparkle, height: 15),
                          SizedBox(width: 6),
                          Text(
                            '異世界初',
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFFC8991F),
                            ),
                          ),
                          SizedBox(width: 6),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _bonus(art.coin, '+${widget.event.cashBonus}G'),
                          const SizedBox(width: 16),
                          _bonus(art.star, '+${widget.event.fameBonus} 名声'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: widget.onDismiss,
                        child: const Text('タップして続ける'),
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
    children: [
      PixelView(sprite, height: 18),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    ],
  );
}
