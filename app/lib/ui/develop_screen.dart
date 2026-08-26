import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../game/game_controller.dart';
import '../game/providers.dart';

/// PB開発 (requirements §4, §12.2): pick 2 material slots + 1 method. Missing
/// materials are auto-ordered so the loop stays smooth for new players. The
/// invention overlay (if any) is driven by the controller after the step.
class DevelopScreen extends ConsumerStatefulWidget {
  const DevelopScreen({super.key});
  @override
  ConsumerState<DevelopScreen> createState() => _DevelopScreenState();
}

class _DevelopScreenState extends ConsumerState<DevelopScreen> {
  int? _matA;
  int? _matB;
  int _method = 0;

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final b = game.balance;

    final canDevelop = _matA != null && _matB != null && game.isAlive;
    final cost = canDevelop
        ? b.materials[_matA!].cost + b.materials[_matB!].cost
        : 0;
    final affordable = game.state.funds >= cost;

    return Scaffold(
      appBar: AppBar(title: const Text('PB開発')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _slot('素材スロット 1', _matA, (i) => setState(() => _matA = i), b),
          const SizedBox(height: 12),
          _slot('素材スロット 2', _matB, (i) => setState(() => _matB = i), b),
          const SizedBox(height: 12),
          const Text('製法', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < b.methods.length; i++)
                ChoiceChip(
                  label: Text(b.methods[i]),
                  selected: _method == i,
                  onSelected: (_) => setState(() => _method = i),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: canDevelop && affordable
                ? () => _develop(game, context)
                : null,
            icon: const Icon(Icons.science),
            label: Text(canDevelop
                ? '開発する（素材費 ${cost}G）'
                : '素材を2つ選んでください'),
          ),
          if (canDevelop && !affordable)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('資金が足りません', style: TextStyle(color: Colors.red)),
            ),
          const Divider(height: 32),
          Text('発見済みレシピ（${game.state.discoveries}種）',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final r in b.recipes)
            if (game.state.discovered[r.id])
              ListTile(
                dense: true,
                leading: Icon(r.invention ? Icons.auto_awesome : Icons.inventory_2,
                    color: r.invention ? const Color(0xFFC8991F) : null),
                title: Text(r.name),
                subtitle: Text('売値 ${r.basePrice}G'),
              ),
        ],
      ),
    );
  }

  Widget _slot(
      String label, int? selected, ValueChanged<int> onPick, Balance b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in b.materials)
              ChoiceChip(
                label: Text('${m.name} (${m.cost}G)'),
                selected: selected == m.id,
                onSelected: (_) => onPick(m.id),
              ),
          ],
        ),
      ],
    );
  }

  void _develop(GameController game, BuildContext context) {
    final a = _matA!;
    final bId = _matB!;
    // Auto-order the needed materials, then develop, then advance one week so
    // the player sees the result immediately (§4 — instant discovery feedback).
    if (a == bId) {
      game.reserve(OrderMaterial(a, 2));
    } else {
      game.reserve(OrderMaterial(a, 1));
      game.reserve(OrderMaterial(bId, 1));
    }
    game.reserve(Develop(a, bId, _method));
    game.step();
    // On a fresh invention, return to the main screen so the overlay (rendered
    // there) plays over the whole screen — the §12.5 emotional peak.
    if (game.pendingInvention != null && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
