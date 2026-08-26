import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/entitlements.dart';
import '../game/providers.dart';

/// 完全版 paywall (§14). Shows the dynamic benefit ("+N項目を解放" — AC-16, from
/// balance) and the 購入 / 復元 actions (restore is required by App Store 3.1.1
/// and appears here + in Settings). The stub IAP is unavailable in release, so
/// the button is disabled with a 準備中 note until RevenueCat lands (M4).
Future<void> showPaywall(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _PaywallSheet(),
  );
}

class _PaywallSheet extends ConsumerWidget {
  const _PaywallSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameControllerProvider);
    final s = game.unlockSummary;
    final available = game.iapAvailable;

    Future<void> notify(String msg) async {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '完全版',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (game.isFull)
              const Text('✔ 購入済みです。ありがとうございます！', textAlign: TextAlign.center)
            else ...[
              Text(
                '・魂の記憶の完全版ノードを +${s.unlockedByFull} 項目 解放\n'
                '・初期資金・設備・生産効率などの恒久強化を解放',
                style: const TextStyle(height: 1.6),
              ),
              const SizedBox(height: 8),
              const Text(
                '※ 種族・自動化・倍速×3 などの高度な機能は、今後の'
                'アップデートで順次有効化されます。',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: available
                    ? () async {
                        final ok = await game.purchaseFull();
                        await notify(ok ? '完全版を購入しました' : '購入に失敗しました');
                        if (ok && context.mounted) Navigator.of(context).pop();
                      }
                    : null,
                child: Text(
                  available ? '完全版を購入（$fullVersionPriceLabel）' : '準備中（近日公開）',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final ok = await game.restorePurchases();
                  await notify(ok ? '購入を復元しました' : '復元できる購入がありません');
                  if (ok && context.mounted) Navigator.of(context).pop();
                },
                child: const Text('購入を復元'),
              ),
              if (!available)
                const Text(
                  '※ ストア連携は次のアップデートで有効になります',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              const Divider(height: 20),
              // Legal (要件§14.4 / §23.3): 価格・非消耗・追加課金なし＋各リンク。
              Text(
                '$fullVersionPriceLabel 買い切り（非消耗）。一度の購入で永続、'
                '追加課金なしでエンディングまで遊べます。',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  for (final t in const ['利用規約', 'プライバシー', '特定商取引法に基づく表記'])
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => notify('$t は次のアップデートで公開します'),
                      child: Text(t, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
