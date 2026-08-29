# 面白さ改修 統合ロードマップ（fun-overhaul）

出典: `/game-review` 監査（2026-08-29, weighted 4.85/10 = NEEDS WORK）。
アーティファクト: `~/.gstack/projects/granite-dust/ijichiyuuta-granite-dust-game-review-20260829-230733.md`

## 背景（監査の一言結論）
数値・経済・決定論は健全。だが**プレイヤーに非自明な意思決定が一つも無く、看板の「発明」がくじ引き**として実装されている。独立2体＋コード直読みの3分析が同一根本原因に収束。面白さの本丸は Core Loop(4/10) と Motivation(3/10)。

## 設計原則（この改修で貫くこと）
1. **本丸＝主要動詞に意思決定を注入**。「進めるを押す」→「市場圧の下で賢い一手」。ジュース/継続は従。
2. **既存データの再配線を優先**（75レシピ・カテゴリ・季節・desc、`reveal_material`等の死にノード）。新サブシステムは最小。
3. **鉄則厳守**：バランス値は`assets/balance/*.json`（二重コピーbyte一致）／ゲームロジックはpure Dart core（Flutter import禁止）／`tool/check_forbidden.sh`（IO/浮動小数/実時計/ハッシュ集合の禁止）／全テスト緑・壊れたgate状態でcommitしない。
4. **決定論に触る変更（engine）だけ gate方式**（計画→監査→実装→再監査→是正）＋headless hash＋cross-archで担保。app層のみの変更（UI/演出/fromMeta）はheadless不変＝低リスク。

## 依存関係
```
M-Fun-0 (Juice+餌)  ── 独立・ゼロ決定論リスク ── まず着手（即体感）
        │
M-Fun-1 (発明改修)  ── 本丸・主にapp層＋node配線 ── 面白さの跳ね上がり
        │                         │
        │                         └─ hint_inherit / reveal_material を機能化
        ▼
M-Fun-2 (流行アービトラージ) ── engine変更・要gate・要経済再校正 ── 最高リスク
        │
        ▼
M-Fun-3 (メタ深化)  ── trend_lead/reveal_material を fromMeta 完全配線
                       ── 3周目が「金持ち」でなく「賢い」プレイに
```
順序の理由：ゼロリスクの即効(0)で体感を先に上げ、本丸(1)で主要動詞を変え、その決定が市場で報われる文脈(2)を足し、メタ(3)で周回差を賢さに。2は決定論エンジンを触るので独立マイルストーンに隔離。

---

## M-Fun-0 — ジュース＆転生の餌（Quick Win）
**目的**: 最頻ビート（売上・昇格）と転生に体感報酬を付け、分5の退屈を即座に潰す。
**変更（app層のみ・core/balance不変）**:
- 昇格＝全画面演出：`InventionOverlay`パターンを再利用した`RankUpOverlay`（店スプライトが育つ`art.shopForRank`は既存）。§12.5昇格演出の実装。
- 売上＝HUD資金の数字アニメ＋`先週の売上`着地時のコインpop。既存`Sfx.coin/rankUp`（chiptune）を発火。
- 転生の餌：生涯終了バナーに「2周目：まだ見ぬ商品◯種が発明可能」（§14.3・現UI欠落）＋次の人生の頭出しプレビュー文（露店スタート/初期資金/新帯）。
**工数**: ~20-30h（1〜1.5週）｜**リスク**: 低（headless不変・balance_hash不変）
**完了条件**: goldens更新・全テスト緑・`diff -r`一致・analyze/check_forbidden クリーン。
**KPI狙い**: 「良いことが起きた感」。分5離脱の初期緩和。

## M-Fun-1 — 発明を「くじ」→「導かれた発見」（本丸）
**目的**: 看板ピラーを機構で裏付ける。プレイヤーの知識を"入力"に変える唯一の変更。
**変更**:
- develop_screen再設計：**前世の記憶＝アイデアカード**（「冷たくて甘い夏の菓子」等のヒントを提示→どのローカル素材×製法かを推理）。
- **未試行数カウンタ**（§12.2既定・未実装、`discovered[]`から導出＝app側）。
- **「惜しい！」近接フィードバック**：素材1つ or 製法が一致した near-miss を提示（`balance.recipes`からapp側で導出、engine不変を優先。必要なら`TickResult`に近接情報を足すが決定論draw不変を厳守）。
- **30%素材開示ヒント**（§4.3）＝soul-memoryの`reveal_material`/`hint_inherit`を機能化（`functionalModTypes`拡張→paywall自動追従）。
**変更ファイル**: `app/lib/ui/develop_screen.dart`（主）／`app/lib/game/game_controller.dart`（近接導出）／`packages/core/lib/src/state.dart`（fromMetaでhint系配線）／`assets/balance/unlocks.json`は既存。engine coreは原則不変（触るなら最小＋gate）。
**工数**: ~50-70h（3〜4週）｜**リスク**: 中（app中心。engineに触れる場合のみ要headless再確認）
**完了条件**: 発明が「推理して当てる」体験になる／near-missで粘れる（無言ロス廃止）／未試行数が見える／hint系ノードが実効果を持つ。全テスト緑・決定論不変。
**KPI狙い**: churn beat（分3-8）をコアの面白さへ転換。意思決定密度↑。

## M-Fun-2 — 流行・季節を市場読みアービトラージに（要gate・最高リスク）
**目的**: M-Fun-1の「知識の応用」にタイミングの掛け金を足す。
**機構修正（決定論engine）**:
- 流行需要を共有プールへ自動配分せず、**当該カテゴリを生産した者だけが取れるボーナスプール**に分離（現状は流行無視でも自動取得＝反応価値ゼロを是正）。
- market有効時のみ追加挙動＝market無効はbyte一致を維持（既存§2.2契約を踏襲）。
- 「この街は今［カテゴリ］を欲している」を`main_screen`で前面化。
**変更ファイル**: `packages/core/lib/src/engine.dart`（water-fill/trend）／`assets/balance/market.json`／`packages/headless/lib/src/*_bot.dart`（trend捕捉botで実証）／`app/lib/ui/main_screen.dart`。
**必須プロセス**: **gate方式**（計画→監査→実装→再監査）。headless決定論hash＋cross-arch照合。`bin/calibrate.dart`で経済再校正＋`--gate`でAC再ベースライン。
**工数**: ~40-60h（2〜3週）｜**リスク**: 高（決定論・経済カーブに影響）
**完了条件**: 流行反応の手動優位が実測で出る（trendAware ON/OFF差>0＝v0.9で未実現だった項目の決着）／全hard gate PASS／replay bit一致。
**KPI狙い**: 主要動詞が「進めるを押す」→「市場を読んで賢い一手」。

## M-Fun-3 — メタ深化（周回差を賢さへ）
**目的**: 3周目が1周目より"賢い"プレイになる（倍率でなく戦略）。
**変更（app/fromMeta層・headless不変）**:
- `trend_lead`（流行予告を早く見る）／`reveal_material`（初期ヒント枠）を`state.fromMeta`で完全配線（M-Fun-1/2で機能が存在した後）。
- soul-memoryツリーに視覚階層（取得済/未取得silhouette・前提線）。転生前に「この記憶で次はどう変わるか」を具体プレビュー。
**変更ファイル**: `app/lib/ui/soul_memory_screen.dart`／`packages/core/lib/src/state.dart`（fromMeta）／`assets/balance/unlocks.json`。
**工数**: ~25-35h（1.5〜2週）｜**リスク**: 中（fromMetaはapp限定・determinism CI維持）
**完了条件**: 死にノードゼロ（全ノードに実効果 or 明示「今後」）／転生が"高揚"に。
**KPI狙い**: §15 2周目突入率70%・完全版CTAの根拠強化。

---

## 横断制約（毎マイルストーン）
- `assets/balance` と `app/assets/balance` の byte一致（CI `diff -r`）。
- core purity（`tool/check_forbidden.sh`）＋ headless meta-less。
- 全テスト緑（core/headless/app）＋ goldens整合。
- 節目ごとに メモリ更新＋commit＋push＋報告（ユーザー指示）。
- engine変更（M-Fun-2）のみ gate方式＋cross-arch hash。

## 概算合計
~135-195h ＝ **8〜10週**（20h/週）。リリース目標 2027-04下旬に対し十分な猶予。順序上、M-Fun-0/1だけでも体感は大きく改善（＝早期に「面白い版」の芯が立つ）。

## 未確定・要ユーザー判断
- 発明UIの方向性：「アイデアカード推理」型 vs「素材から逆算ヒント」型（M-Fun-1着手前に1問）。
- M-Fun-2の流行機構は経済カーブに影響＝再校正必須。既存AC-09/10のbaseline引き直しを許容するか。
- スコープ：4本すべてやるか、M-Fun-0/1で一旦リリース評価するか。
