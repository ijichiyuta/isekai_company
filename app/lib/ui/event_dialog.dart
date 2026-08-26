import 'package:flutter/material.dart';
import 'package:isekai_core/isekai_core.dart';

import 'theme.dart';

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
          child: Card(
            margin: const EdgeInsets.all(24),
            color: const Color(0xFFFBF3DE),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_kindLabel(event.kind),
                      style: const TextStyle(fontSize: 12, color: kFame)),
                  const SizedBox(height: 4),
                  Text(event.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(event.body,
                      style: const TextStyle(fontSize: 14, height: 1.4)),
                  const SizedBox(height: 20),
                  for (var i = 0; i < event.choices.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          onPressed: () => onChoose(i),
                          child: Text(event.choices[i].label),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _kindLabel(String kind) => switch (kind) {
        'kingdom' => '👑 王国',
        'disaster' => '⚠ 危機',
        'opportunity' => '✨ 好機',
        'character' => '👤 人物',
        'hero' => '⚔ 勇者',
        'reincarnator' => '🌀 転生者',
        'cycle' => '🔁 巡る記憶',
        _ => 'できごと',
      };
}
