import 'package:flutter/material.dart';

import 'game_ui.dart';
import 'pixel/pixel_art.dart';
import 'pixel/sprites.dart' as art;
import 'theme.dart';

/// The intro sequence (requirements §13): 前世（過労死）→ 転生 → 目標提示. Skippable
/// (§13, §12.2 #20). Kept to a few cards so the "90-second" onboarding stays
/// short; the guided first-develop (pudding) follows in [GameRoot].
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = <(_Cut, String, String)>[
    (_Cut.past, '深夜のコンビニ、独りきりの棚卸し。', 'コンビニチェーンのスーパーバイザー。発注も、廃棄も、棚割りも、ぜんぶ抱えて——'),
    (_Cut.past, '「もう、限界だ……」', '過労で倒れた、その意識が途切れる瞬間。'),
    (
      _Cut.goddess,
      '女神「あなたに前世の記憶を授けます」',
      '気づけば見知らぬ異世界。手には元手 100ゴールドと、現代日本の商売の知識だけ。',
    ),
    (
      _Cut.goal,
      'これは“商店経営”シミュレーション',
      '流れはシンプル。①開発で新商品を生む → ②生産して作る → ③並べれば自動で売れる → '
          '④「次の週へ」で時を進めて稼ぐ → ⑤名声と資産でランクを上げる。',
    ),
    (
      _Cut.goal,
      'まずは「PB開発」で商品を発明しよう',
      'この世界にまだ無い商品を作れば、街の人々が驚き、名声とお金が舞い込む。行商人から大商会主へ！',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _pages.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFF2E2A24),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: widget.onDone,
                child: const Text(
                  'スキップ',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final (cut, title, body) = _pages[i];
                  return _Card(cut: cut, title: title, body: body);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _page ? kGold : Colors.white24,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: PixelButton(
                  onTap: last
                      ? widget.onDone
                      : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        ),
                  fill: kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Center(
                    child: Text(
                      last ? 'はじめる' : '次へ',
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
    );
  }
}

enum _Cut { past, goddess, goal }

class _Card extends StatelessWidget {
  const _Card({required this.cut, required this.title, required this.body});
  final _Cut cut;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final (sprite, px) = switch (cut) {
      _Cut.past => (art.konbini, 2.0), // his previous world — the 24h コンビニ
      _Cut.goddess => (art.goddess, 2.0),
      _Cut.goal => (art.beaker, 4.0),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 172,
            child: Center(child: PixelView(sprite, pixelSize: px)),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
