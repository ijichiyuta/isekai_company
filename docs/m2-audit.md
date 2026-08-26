# M2 実装後監査 結果と是正

**日付**: 2026-08-26 / **方式**: Opus並列3体で実装コードを敵対的監査（実走で裏取り）

## 判定サマリー

3体とも **条件付きGO**。M2の中核成果物（第2層ループ・生涯評価・転生・破産・43種・30本・events+pityによるAC-05解決・hardゲート全PASS・96テスト緑・AC-14実ビルド実証・**M1回帰なし**）は実測で健全。ただしM3着手前に潰すべき実バグ・検証空白を指摘。

## 監査が確認した健全性（実測）
- イベントの決定論完全性: 毎tick厳密2ドロー・候補数/コマンド/pending非依存、events空でストリーム未消費、save/load中断でbit一致（60シード×多セーブ点）。
- events空の contentHash・toJson が従来と完全一致（A-D1/A-D2）。効果適用・ChooseEvent・balance例外正規化すべて安全。
- 全43combо重複ゼロ（自力列挙照合）、ADR-0001追記のみ厳守（id0-10不変）、water-fill配分の全境界正しい。
- hardゲート AC-04/05/07 が seed 1/2/999 で安定PASS。AC-14 は実release buildでdebugシンボル不在を実証。

## 是正（本監査で修正済み）

| ID | 指摘（重大度） | 是正 |
|---|---|---|
| D-2 | **cycleイベントが実機で永久発火しない**（App層バグ）。`rebirth()` が lifeNumber を GameState に渡さず、周回専用4本が死にコンテンツ | `game_controller.rebirth()` に `lifeNumber:` を配線。EV-13テスト追加 |
| D-1 | shuffle-bag reset が fame-gating で履歴を消し、同一周回でイベント再出現の恐れ（§3.7違反、Medium） | reset を「真の満杯（全非forcedが発火）時のみ」に限定。ただし**pity強制発火時は再showを許容**（AC-05のmaxGap保証を優先）。`_bagFull` 追加、EV-14テスト |
| H-2 | **AC-09が測定コードすら無い**（gate.dartに判定なし＝逃げ、High） | gate.dart に AC-09（§10.2カーブ vs 各チェックポイント±50%）を soft で実装。honestに乖離を報告 |
| H-1 | events込みの決定論がクロスアーチCI照合の外（実ゲーム構成が未検証、High） | `--with-events` フラグ追加。CIのcross-archでevents込みhashも両アーキ比較 |

検証: core60+headless21+app17=98テスト通過。GATE OK（hard全PASS）。AC-05は是正後も p50/p90/maxGap=19/58/58 で PASS。events込み `--verify-replay` 決定論OK。

## M3への繰越（監査が指摘、実装は M3）

| # | 項目 | 重大度 |
|---|---|---|
| C-1 | **AC-08 御用達到達0%＝経済カーブ形状の破綻**（§10.2は near-geometric、実装は容量律速の線形＝序盤+25637%/終盤-52%）。AC-09で可視化済み。§10.2改訂 or economyオーバーホールのADR＋専用バランス反復（1万周） | High |
| C-2 | **発明品が継続生産で選ばれない**（周1発見の発明はプリン/石鹸のみ、粗利で非発明品に負ける）。§1.1中核訴求の空洞。band/粗利重み付け配分 or 発明プレミアム | High |
| C-3 | AC-10 手動優位+609%: 自動値付け#15・自動発注#16（魂の記憶）実装後に再校正 | High |
| C-4 | AC-06 実機計測: Flutterでメニュー込み1周を実測（§24完了条件の実質判定） | High |
| C-5 | AC-15 balance/schemaマイグレーション表（現状=不一致破棄）。ペイウォール/IAP前必須 | Medium |
| C-6 | 魂の記憶ツリー22項目＋メタ永続化＋2周目短縮（M3本体）、tutorial永続化 | Medium |
| C-7 | §10.1粗利レンジ逸脱5件（微調整）、実AIアセット量産テスト、生涯スコアε項 | Low |
