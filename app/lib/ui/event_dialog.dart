import 'package:flutter/material.dart';
import 'package:isekai_core/isekai_core.dart';

import 'game_ui.dart';

/// Event dialog (requirements §3.7, §12.2 #12). Shows the event and its choices;
/// tapping a choice applies its effects (via the controller) and resumes play.
class EventDialog extends StatelessWidget {
  const EventDialog({super.key, required this.event, required this.onChoose});
  final EventDef event;
  final void Function(int choiceIndex) onChoose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: PixelBox(
                fill: const Color(0xFFFBF3DE),
                bevel: 3,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _KindChip(kind: event.kind),
                    const SizedBox(height: 8),
                    Text(
                      event.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kInkText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      event.body,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: kInkText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < event.choices.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity,
                          child: PixelButton(
                            onTap: () => onChoose(i),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Center(
                              child: Text(
                                event.choices[i].label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: kInkText,
                                ),
                              ),
                            ),
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

/// A small colored tag for the event category (§3.7) — replaces the old emoji
/// prefixes with a designed chip so the world reads intentional, not AI-ish.
class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (kind) {
      'kingdom' => ('王国', const Color(0xFFB8860B)),
      'disaster' => ('危機', const Color(0xFFC0392B)),
      'opportunity' => ('好機', const Color(0xFF2E9E5B)),
      'character' => ('人物', const Color(0xFF3A7BBF)),
      'hero' => ('勇者', const Color(0xFFD2691E)),
      'reincarnator' => ('転生者', const Color(0xFF2AA198)),
      'cycle' => ('巡る記憶', const Color(0xFF6A4FB6)),
      _ => ('できごと', const Color(0xFF6E665A)),
    };
    return PixelBox(
      raised: false,
      fill: const Color(0xFFF1E4C4),
      bevel: 1,
      outline: 1.5,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
