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

/// A selectable pill rendered as a pixel button (gold when selected). An
/// optional [icon] shows the material/thing at a glance so players don't have
/// to read every label.
Widget _chip(
  String label,
  bool selected,
  VoidCallback? onTap, {
  PixelSprite? icon,
}) => PixelButton(
  onTap: onTap,
  fill: selected ? kAccent : kPanel,
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        PixelView(icon, height: 22),
        const SizedBox(width: 6),
      ],
      Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.w600,
          fontSize: 15,
          color: kInkText,
        ),
      ),
    ],
  ),
);

/// 商品開発 (requirements §4, §12.2) — reframed as GUIDED DISCOVERY (M-Fun-1):
/// the player recalls a product from their past life (a 前世の記憶 card) and
/// DEDUCES which two local materials + method reproduce it. A miss returns a
/// "hot/cold" hint (§4.3 手応え) instead of silently eating the materials, so
/// invention feels like clever modern-knowledge arbitrage, not a blind lottery.
/// The card/hint layer is entirely UI-side — the deterministic engine is
/// untouched (it still discovers on an exact (matA,matB,method) match).
class DevelopScreen extends ConsumerStatefulWidget {
  const DevelopScreen({super.key, this.tutorial = false});

  /// When true, pre-selects the pudding recipe (小麦×卵＋冷却) and its memory
  /// card + a hint, guaranteeing the first-invention beat (§13, first_invention).
  final bool tutorial;

  @override
  ConsumerState<DevelopScreen> createState() => _DevelopScreenState();
}

class _DevelopScreenState extends ConsumerState<DevelopScreen> {
  int? _matA;
  int? _matB;
  int _method = 0;

  /// The 前世の記憶 card the player is trying to reproduce (recipe id), or null
  /// for free experimentation. Drives the riddle + the "hot/cold" hint.
  int? _targetId;

  /// Feedback from the last attempt (a discovery or a near-miss hint), or null.
  String? _resultMsg;
  bool _resultGood = false;

  @override
  void initState() {
    super.initState();
    if (widget.tutorial) {
      _matA = 0; // 小麦
      _matB = 1; // 卵
      _method = 0; // 冷却
      _targetId = 0; // プリン
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(gameControllerProvider);
    final b = game.balance;
    final s = game.state;

    final canDevelop = _matA != null && _matB != null && game.isAlive;
    final cost = canDevelop
        ? b.materials[_matA!].cost + b.materials[_matB!].cost
        : 0;
    final affordable = s.funds >= cost;

    // Undiscovered ideas the player can chase this life (within the band that
    // 魂の記憶 has unlocked). These are the "memories" to reproduce.
    final ideas = <RecipeDef>[
      for (final r in b.recipes)
        if (!s.discovered[r.id] && r.band <= s.allowedBandMax) r,
    ];

    // 魂の記憶 invention aids (M-Fun-1 slice 2, display-only): 記憶の索引 reveals
    // material(s); 閃きの残滓 fully reveals a fraction of recipes (stable by id).
    final revealCount = game.revealMaterialCount;
    final inheritPct = game.hintInheritPercent;
    bool inheritedOf(RecipeDef r) => inheritPct > 0 && r.id % 100 < inheritPct;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: pixelAppBar(title: PixelTitle(art.beaker, '商品開発')),
        // The primary action is pinned so it never scrolls off.
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canDevelop && !affordable)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      '資金が足りません',
                      style: TextStyle(
                        color: Color(0xFFB23A2E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: PixelButton(
                    onTap: canDevelop && affordable
                        ? () => _develop(game, context)
                        : null,
                    fill: canDevelop && affordable ? kAccent : kPanel,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PixelView(art.beaker, height: 18),
                          const SizedBox(width: 6),
                          Text(
                            canDevelop
                                ? '開発する（素材費 ${gold(cost)}）'
                                : '素材を2つ選んでください',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kInkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            maeseMemo('前世の記憶　まだ無い商品を思い出す。カードを選び、素材2つと製法で"再現"を推理せよ。'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (widget.tutorial) _tutorialHint(),
                  // --- 前世の記憶: the ideas to reproduce (tap to target) ---
                  Row(
                    children: [
                      PixelView(art.sparkle, height: 16),
                      const SizedBox(width: 6),
                      Text(
                        '前世の記憶（未発見 ${ideas.length}種）',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: kInkText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '思い出した品を選び、この世界の素材で再現しよう。',
                    style: TextStyle(fontSize: 12, color: kInkText),
                  ),
                  const SizedBox(height: 8),
                  if (ideas.isEmpty)
                    const Text(
                      'この人生の記憶はすべて再現した。転生すれば、まだ見ぬ記憶が甦る。',
                      style: TextStyle(fontSize: 12.5, color: kInkText),
                    ),
                  // The memory list can be long — bound it in its own scroll box
                  // so the deduction pickers below stay near the top (reachable
                  // without a marathon scroll, and mounted for interaction).
                  if (ideas.isNotEmpty)
                    SizedBox(
                      height: 150,
                      child: PixelBox(
                        raised: false,
                        fill: const Color(0xFFF6EFDA),
                        bevel: 1,
                        outline: 1.5,
                        padding: const EdgeInsets.all(8),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final r in ideas)
                                _ideaCard(
                                  r,
                                  _targetId == r.id,
                                  inheritedOf(r),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (_targetId != null)
                    _riddleBox(
                      b,
                      b.recipes[_targetId!],
                      revealCount,
                      inheritedOf(b.recipes[_targetId!]),
                    ),
                  _slot(
                    '素材スロット 1',
                    _matA,
                    (i) => setState(() {
                      _matA = i;
                      _resultMsg = null;
                    }),
                    b,
                  ),
                  const SizedBox(height: 12),
                  _slot(
                    '素材スロット 2',
                    _matB,
                    (i) => setState(() {
                      _matB = i;
                      _resultMsg = null;
                    }),
                    b,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '製法',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kInkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < b.methods.length; i++)
                        _chip(
                          methodJa(b.methods[i]),
                          _method == i,
                          () => setState(() {
                            _method = i;
                            _resultMsg = null;
                          }),
                        ),
                    ],
                  ),
                  if (_resultMsg != null) ...[
                    const SizedBox(height: 12),
                    _resultBox(),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    '発見済みレシピ（${s.discoveries}種）',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kInkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final r in b.recipes)
                    if (s.discovered[r.id]) _discoveredTile(r),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tutorialHint() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: PixelBox(
      fill: const Color(0xFFFBEBBE),
      padding: const EdgeInsets.all(10),
      child: const Text(
        '前世の記憶がひらめく——「小麦 × 卵 ＋ 冷却」で作れるはず！\n'
        '下の「開発する」を押してみよう。',
        style: TextStyle(fontSize: 13, color: kInkText),
      ),
    ),
  );

  /// One 前世の記憶 card: category icon + name (+✦ for an invention, + a lit
  /// bulb when 閃きの残滓 has made this memory vivid). Tapping sets the deduction
  /// target (tap again to clear).
  Widget _ideaCard(RecipeDef r, bool selected, bool inherited) => PixelButton(
    onTap: () => setState(() {
      _targetId = selected ? null : r.id;
      _resultMsg = null;
    }),
    fill: selected ? kAccent : kPanel,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelView(art.categoryIcon(r.category), height: 20),
        const SizedBox(width: 5),
        Text(
          r.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            color: kInkText,
          ),
        ),
        if (r.invention) ...[
          const SizedBox(width: 4),
          PixelView(art.sparkle, height: 12),
        ],
        if (inherited) ...[
          const SizedBox(width: 3),
          const Icon(Icons.lightbulb, size: 13, color: Color(0xFFC8991F)),
        ],
      ],
    ),
  );

  /// The selected memory's riddle: what to reproduce + the past-life flavor as
  /// the clue. When 魂の記憶 aids are owned, a 手がかり line reveals material(s)
  /// (記憶の索引) or the whole combo (閃きの残滓, for "vivid" memories).
  Widget _riddleBox(Balance b, RecipeDef r, int revealCount, bool inherited) {
    String? hint;
    if (inherited) {
      hint =
          '記憶が鮮明——${b.materials[r.matA].name} × ${b.materials[r.matB].name} ＋ ${methodJa(b.methods[r.method])}';
    } else if (revealCount >= 2) {
      hint =
          '手がかり：素材は「${b.materials[r.matA].name}」と「${b.materials[r.matB].name}」';
    } else if (revealCount == 1) {
      hint = '手がかり：素材のひとつは「${b.materials[r.matA].name}」';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PixelBox(
        fill: const Color(0xFFEAF3E0),
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PixelView(art.categoryIcon(r.category), height: 22),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '「${r.name}」を再現する',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: kInkText,
                    ),
                  ),
                ),
              ],
            ),
            if (r.desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                r.desc,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: Color(0xFF6B5330),
                ),
              ),
            ],
            const SizedBox(height: 6),
            const Text(
              '前世の知識で、素材2つと製法を推理しよう。',
              style: TextStyle(fontSize: 12, color: kInkText),
            ),
            if (hint != null) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb,
                    size: 15,
                    color: Color(0xFFC8991F),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A6A1E),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultBox() => PixelBox(
    raised: false,
    fill: _resultGood ? const Color(0xFFDDEFCB) : const Color(0xFFF6E7CE),
    bevel: 1,
    outline: 1.5,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    child: Row(
      children: [
        PixelView(_resultGood ? art.sparkle : art.beaker, height: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            _resultMsg!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _resultGood
                  ? const Color(0xFF3C6B2E)
                  : const Color(0xFF9A5A2E),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _discoveredTile(RecipeDef r) => PixelListTile(
    leading: PixelView(
      art.categoryIcon(r.category),
      height: 28,
      semanticLabel: categoryJa(r.category),
    ),
    title: Text(r.name),
    subtitle: r.desc.isEmpty
        ? Text('売値 ${gold(r.basePrice)}')
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('売値 ${gold(r.basePrice)}'),
              const SizedBox(height: 2),
              Text(
                r.desc,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: Color(0xFF9A7A4A),
                ),
              ),
            ],
          ),
  );

  Widget _slot(
    String label,
    int? selected,
    ValueChanged<int> onPick,
    Balance b,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, color: kInkText),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in b.materials)
              _chip(
                '${m.name}（${gold(m.cost)}）',
                selected == m.id,
                () => onPick(m.id),
                icon: art.materialIcon(m.id),
              ),
          ],
        ),
      ],
    );
  }

  void _develop(GameController game, BuildContext context) {
    final b = game.balance;
    final a = _matA!;
    final bId = _matB!;
    final before = game.state.discoveries;
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
      return;
    }
    // Otherwise stay: either a non-invention recipe was found, or it missed and
    // the player earns a "hot/cold" hint toward the target (§4.3).
    final gained = game.state.discoveries > before;
    setState(() {
      if (gained) {
        final lo = a <= bId ? a : bId;
        final hi = a <= bId ? bId : a;
        final made = b.findRecipe(lo, hi, _method);
        _resultGood = true;
        _resultMsg = made != null ? '「${made.name}」を発見！' : '新しい商品を発見！';
        _targetId = null;
      } else {
        _resultGood = false;
        _resultMsg = _nearMiss(b);
      }
    });
  }

  /// A "hot/cold" hint after a miss, derived in-app from the SELECTED target's
  /// true recipe (§4.3 手応え). Turns silent material loss into a narrowing
  /// deduction. No engine involvement — the app already knows the recipe table.
  String _nearMiss(Balance b) {
    final t = _targetId;
    if (t == null) return 'はずれ……別の組み合わせを試してみよう。';
    final r = b.recipes[t];
    final guess = <int>{_matA!, _matB!};
    final target = <int>{r.matA, r.matB};
    final shared = guess.intersection(target);
    final methodOk = r.method == _method;
    if (shared.length >= target.length && !methodOk) {
      return '素材は完璧！ 製法だけが違う。';
    }
    if (methodOk && shared.isNotEmpty) {
      return '製法は合っている。あとは素材ひとつ。';
    }
    if (shared.isNotEmpty) {
      return '素材「${b.materials[shared.first].name}」は合っている。手がかりだ。';
    }
    if (methodOk) return '製法は合っているかも。素材を見直そう。';
    return 'どれも手がかりにならなかった……別の記憶を探ろう。';
  }
}
