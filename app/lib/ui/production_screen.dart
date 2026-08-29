import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isekai_core/isekai_core.dart';

import '../game/format.dart';
import '../game/game_controller.dart';
import '../game/providers.dart';
import 'background.dart';
import 'game_ui.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;

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

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: pixelAppBar(title: PixelTitle(art.factoryIcon, '生産')),
        body: ListView(
          children: [
            _UpgradePanel(game: game),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '週あたり生産能力: ${game.weeklyCapacity} 個'
                '（従業員 ${game.state.employees}人・設備Lv${game.equipmentLevel}）',
                style: const TextStyle(color: kInkText, fontSize: 13),
              ),
            ),
            if (known.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'まずPB開発でレシピを発見しましょう',
                    style: TextStyle(color: kInkText),
                  ),
                ),
              ),
            for (final r in known)
              PixelListTile(
                leading: PixelView(
                  art.categoryIcon(r.category),
                  height: 28,
                  semanticLabel: categoryJa(r.category),
                ),
                title: Text(r.name),
                subtitle: Text(
                  '完成品在庫 ${game.state.productStock[r.id]} '
                  '・ 素材 ${b.materials[r.matA].name}/${b.materials[r.matB].name}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final qty in [1, 5])
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: PixelButton(
                          // Reserve the needed materials too, so production
                          // succeeds regardless of order (§2.1 予約制; applied
                          // when the week advances).
                          onTap: game.isAlive
                              ? () {
                                  if (r.matA == r.matB) {
                                    game.reserve(
                                      OrderMaterial(r.matA, qty * 2),
                                    );
                                  } else {
                                    game.reserve(OrderMaterial(r.matA, qty));
                                    game.reserve(OrderMaterial(r.matB, qty));
                                  }
                                  game.reserve(Produce(r.id, qty));
                                }
                              : null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            '作+$qty',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kInkText,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: PixelBox(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '設備・品質への再投資',
              style: TextStyle(fontWeight: FontWeight.bold, color: kInkText),
            ),
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
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
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kInkText,
                ),
              ),
              Text(
                sub,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A6A44)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        PixelButton(
          onTap: enabled ? onTap : null,
          fill: enabled ? kAccent : kPanel,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            costLabel,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kInkText,
            ),
          ),
        ),
      ],
    );
  }
}
