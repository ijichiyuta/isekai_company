import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../game/format.dart';
import '../game/game_controller.dart';
import '../game/providers.dart';

/// 生産 (requirements §4, §12.2): produce discovered recipes from materials.
/// Capacity = base + employees × output; the engine clamps to stock/capacity.
class ProductionScreen extends ConsumerWidget {
  const ProductionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    final b = game.balance;
    final known = [
      for (final r in b.recipes)
        if (game.state.discovered[r.id]) r,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('生産')),
      body: ListView(
        children: [
          _UpgradePanel(game: game),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '週あたり生産能力: ${game.weeklyCapacity} 個'
              '（従業員 ${game.state.employees}人・設備Lv${game.equipmentLevel}）',
            ),
          ),
          if (known.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('まずPB開発でレシピを発見しましょう')),
            ),
          for (final r in known)
            ListTile(
              title: Text(r.name),
              subtitle: Text(
                '完成品在庫 ${game.state.productStock[r.id]} '
                '・ 素材 ${b.materials[r.matA].name}/${b.materials[r.matB].name}',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  for (final qty in [1, 5])
                    OutlinedButton(
                      // Reserve the needed materials too, so production
                      // succeeds regardless of order (§2.1 予約制; applied
                      // when the week advances).
                      onPressed: game.isAlive
                          ? () {
                              if (r.matA == r.matB) {
                                game.reserve(OrderMaterial(r.matA, qty * 2));
                              } else {
                                game.reserve(OrderMaterial(r.matA, qty));
                                game.reserve(OrderMaterial(r.matB, qty));
                              }
                              game.reserve(Produce(r.id, qty));
                            }
                          : null,
                      child: Text('作+$qty'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Equipment (capacity ×) and quality (price ×) reinvestment — the §10.2
/// growth drivers, now player-operable. Upgrades are reserved and apply on the
/// next week (予約制). Costs mirror the engine's geometric curve.
class _UpgradePanel extends StatelessWidget {
  const _UpgradePanel({required this.game});
  final GameController game;

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eqCost = game.equipUpgradeCost();
    final qCost = game.qualityUpgradeCost();
    final priceMult = (game.qualityMultPercent / 100).toStringAsFixed(2);
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '設備・品質への再投資',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _UpgradeRow(
              label: '設備レベル ${game.equipmentLevel} / ${game.equipMaxLevel}',
              sub: '週次生産能力を拡大',
              costLabel: game.canUpgradeEquipment
                  ? '${formatG(eqCost)} で強化'
                  : '最大',
              enabled:
                  game.isAlive &&
                  game.canUpgradeEquipment &&
                  game.state.funds >= eqCost,
              onTap: () {
                game.reserve(UpgradeEquipment());
                _toast(context, '設備強化を予約（次の週に適用）');
              },
            ),
            const Divider(height: 16),
            _UpgradeRow(
              label:
                  '品質 ★${game.qualityStar} / ${game.qualityMaxStar}'
                  '（販売単価 ×$priceMult）',
              sub: 'すべての商品の売値を引き上げ',
              costLabel: game.canUpgradeQuality
                  ? '${formatG(qCost)} で向上'
                  : '最大',
              enabled:
                  game.isAlive &&
                  game.canUpgradeQuality &&
                  game.state.funds >= qCost,
              onTap: () {
                game.reserve(ImproveQuality());
                _toast(context, '品質向上を予約（次の週に適用）');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeRow extends StatelessWidget {
  const _UpgradeRow({
    required this.label,
    required this.sub,
    required this.costLabel,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final String sub;
  final String costLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                sub,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        FilledButton.tonal(
          onPressed: enabled ? onTap : null,
          child: Text(costLabel),
        ),
      ],
    );
  }
}
