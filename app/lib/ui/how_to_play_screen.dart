import 'package:flutter/material.dart';

import 'background.dart';
import 'game_ui.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;

/// 遊び方 — a plain-language explainer a first-time (or returning) player can
/// open anytime. Answers "what is this game?" and "what do I do?" (§12.2 #20 の
/// 常設版). Reachable from the title, the main HUD "?", and Settings.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: pixelAppBar(title: PixelTitle(art.beaker, '遊び方')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _panel(
              'どんなゲーム？',
              '過労で倒れた元コンビニ店長のあなたが、前世の商売知識を武器に'
                  '異世界で商店を営み、「行商人」から「大商会主」へと成り上がる'
                  '経営シミュレーションです。寿命が来たら“転生”し、前世の記憶を'
                  '引き継いで次の人生に挑みます。',
            ),
            const SizedBox(height: 10),
            _loopPanel(),
            const SizedBox(height: 10),
            _panel(
              '目標',
              '商品を売って「資産」と「名声」を貯め、ランクを上げていきましょう。'
                  '寿命を迎えると「魂の記憶」を得て転生でき、次の人生が有利になります。'
                  'まずは開発→生産→販売→「次の週へ」の流れに慣れればOK。',
            ),
            const SizedBox(height: 10),
            _buttonsPanel(),
            const SizedBox(height: 10),
            _panel(
              '困ったら',
              '画面下に「レシピ未発見」「在庫なし」などのヒントが出たら、'
                  'タップするとやるべき画面へ直行できます。迷ったらまず「開発」から。',
            ),
          ],
        ),
      ),
    );
  }

  static Widget _panel(String title, String body) => PixelBox(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: kInkText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(fontSize: 13, height: 1.5, color: kInkText),
        ),
      ],
    ),
  );

  static Widget _loopPanel() => PixelBox(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '遊びの流れ',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: kInkText,
          ),
        ),
        const SizedBox(height: 10),
        _step(art.beaker, '① 開発', '素材2つ＋製法で新しい商品を生み出す。'),
        _step(art.factoryIcon, '② 生産', '発見した商品を作って在庫にする。'),
        _step(art.storefront, '③ 販売', '並べれば毎週“自動で”売れていく。'),
        _step(art.cart, '④ 発注', '素材が足りなければ仕入れる（予約制）。'),
        _step(art.coin, '⑤ 次の週へ', '時を進めて売上・名声を得る。'),
        _step(art.star, '⑥ ランクUP→転生', '資産と名声でランクを上げ、寿命で転生。'),
      ],
    ),
  );

  static Widget _step(PixelSprite icon, String label, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PixelView(icon, height: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: kInkText,
                ),
              ),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Color(0xFF8A6A44),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static Widget _buttonsPanel() => PixelBox(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          '画面下のボタン',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: kInkText,
          ),
        ),
        SizedBox(height: 6),
        Text(
          '開発＝商品づくり／生産＝在庫を作る／販売＝売上と在庫の確認／'
              '発注＝素材の仕入れ。右下の ‖ ×1 ×2 は時間の速さ、'
              '緑の「次の週へ」で1週だけ進みます。',
          style: TextStyle(fontSize: 13, height: 1.5, color: kInkText),
        ),
      ],
    ),
  );
}
