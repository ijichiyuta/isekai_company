# M2 実装計画（並列3ピース）

**版数**: v1（2026-08-26、並列計画立案フェーズ）
**方式**: 計画 → 監査 → 実装 → 再監査（ユーザー指定のゲート方式）
**M2完了条件（要件§24）**: 第2層完成＋商品40種・イベント30本＋バランスゲート有効化 →「1周60分成立」

## ピース分解とファイル所有（衝突回避の要）

| ピース | 担当ファイル（排他） |
|---|---|
| **A: イベントシステム** | `assets/balance/events.json`（新規）＋`app/assets/balance/events.json`／`packages/core/lib/src/events.dart`（新規）／`engine.dart`・`state.dart`・`commands.dart`・`balance.dart`・`isekai_core.dart`（編集）／`app/lib/ui/event_dialog.dart`（新規）・`game_controller.dart`・`main_screen.dart`・`balance_loader.dart` |
| **B: コンテンツ拡張** | `assets/balance/materials.json`・`recipes.json` ＋ `app/assets/balance/` の同コピーのみ |
| **C: バランスゲート** | `assets/balance/economy.json`・`ranks.json`／`packages/headless/`（runner・gate.dart新規・run.dart）／`.github/workflows/ci.yml` |

**唯一の物理共有点**: `engine.dart`（A担当）と C の economy 調整は別物（Cはコード非改変・数値のみ）。`balance.dart` は A のみ編集。→ 実質衝突なし。

## 調整済みインターフェース契約

1. **`Balance.fromJsonMaps` に `eventsJson`（省略可・デフォルト空Map）を A が追加** → C の headless loader / app balance_loader は無改変で通る（B/C を壊さない）。
2. **決定論**: イベント専用RNGストリーム（既存 `rng.dart` stream 3）は **`balance.events` が空ならイベントフェーズ全体をスキップし一切ドローしない**。→ headless（events未指定）の既存ハッシュ完全不変（AC-01/02/03 維持）。events 有効時のみ、ティックあたり固定回数ドロー（コマンド非依存）で決定論維持。
3. **御用達ゲート**: rank3→4 昇格条件に `royalEventCleared` を AND、ただし `balance.events.isNotEmpty` を条件に含める（events 無効な headless では従来どおり fame/assets で昇格）。
4. **計測連携**: A はイベント発火を `TickResult`（または `rewardEvents`）に反映 → C の報酬間隔計測が自動で拾う。**項目名は実装時に A/C 合意**。
5. **セーブ**: schema_version 据え置き。`fromJson` はデフォルトフォールバック（`m['event_log'] ?? []`）で v1 内後方互換。balance_hash 変化による既存セーブ破棄は ADR-0001（MVP＝不一致破棄）で吸収。

## 統合順序

```
C: 報酬間隔計測インフラ＋gate.dart＋CIジョブ骨格（現11種で先行可、soft gate）
  → B: 素材20・レシピ43（40種＋AC-04用にband1=35）
  → A: events.json 30本＋engine統合＋app イベントダイアログ
  → C: economy/ranks 最終校正＋hard gate 化＋夜間10k回帰
```

## ピースA: イベントシステム（要点）

- **events.json スキーマ**: id/kind(kingdom|disaster|opportunity|character|hero|reincarnator|cycle)/title/body/min_life/min_fame/max_fame/weight/forced/choices[{label,effects[{type,value/id}]}]。effect type: funds/fame/grant_recipe/material/product/royal_flag。
- **30本配分**: 王国4(内1=forced fame3000)/災害5/好機5/キャラ6/勇者3/転生者3/周回専用4。**2択以上22本(73%)** ≥50%。
- **抽選**: tick末尾（week++直前）に毎tick固定2ドロー（events有効時）。forced（王室）はRNG非消費の純状態判定。重複=同一周内禁止＋メタ側直近2周で重み低減。効果は `ChooseEvent(id,idx)` コマンドで次tick適用（予約制§2.1）。
- **app**: 発明キューと同型のイベントキュー＋自動ポーズ＋event_dialog。
- **受け入れ**: EV-01〜12（決定論・RNGドロー不変・重複禁止・王室確定発火・御用達ゲート・効果適用・headless回帰ハッシュ不変・widget・balance堅牢化）。
- **注意**: 要件§7.1本文=60本 vs §24 M2=30本 → M2は30本（60本化はM3周2帯）。

## ピースB: コンテンツ拡張（要点）

- **素材 8→20**（id8-19: 米/果実/香辛料/肉/魚/塩/銅鉱石/灰/綿/羊毛/皮革/魔石）。cost 1〜8（§10.1レンジ）。※32種はv0.9（combos探索が寿命内に収まる上限考慮で M2は20）。
- **レシピ 11→43**（id11-42追記）。band1=35（AC-04下限35達成）/band2=6/band3=2。発明8種=20%（既存4＋カレー粉/おにぎり/歯ブラシ/帳面）。6カテゴリ配分・8製法活用・粗利25〜60%（§10.1連続）。
- **ADR-0001追記のみ**: 既存 id 0-10 の意味・数値・combo を不変、末尾追加のみ。
- **balance.dart 全規則適合**: id連番・重複combo禁止(matA≤matB正規化)・band1..3・method参照・range[0,1e15]。
- **最大の依存**: 共有需要プールがid順配分 → 高band/高粗利品が売れない恐れ。C の需要重み付け調整と統合必須。

## ピースC: バランスゲート（要点）

- **報酬間隔計測をheadlessに追加**（coreは無改変）: `runLife` で `TickResult`を受け、`rewardEvents`増分の発生tickを収集→gap分布のp50/p90/maxGap。1tick=1.5s換算（p50≦40s⇔≦26.67tick、p90≦90s⇔≦60tick、3分無報酬⇔≦120tick）。
- **`gate.dart`＋`--gate`**: AC-04〜10を判定しexit code。AC-04(周1発見35〜40)/AC-05(間隔p50/p90/maxGap/周間乖離±30%,steady)/AC-06(tick予算プロキシ,実測はFlutter側)/AC-07(破産steady<5%/attack<30%)/AC-08(steady80%御用達)/AC-09(カーブ±50%,回収型込み)/AC-10(attack vs idle +10〜20%)。
- **1周60分調整**: economy(base_demand/demand_per_fame/fame_per_sales/capacity/invention_mult)＋ranks(min_assets/fame/tax)を暫定→B→A統合後に最終校正。
- **CI**: `balance-gate`ジョブ（PR=200〜500周soft→統合後hard、夜間10k）。
- **未決**: 発見が序盤に固まる構造（AC-05 maxGap悪化）→発見の寿命分散が課題。AC-06のメニュー込み実測はFlutter側。

## 横断リスク

- 共有需要プールのid順配分 ↔ 高band品の売れ行き（B/C統合の核心課題）。
- balance_hash変化で既存セーブ破棄（ADR-0001許容）。
- AC-10 手動優位は自動化(#15/#16)未実装で現状+548%＝M2校正課題。
- イベント本数30 vs 要件本文60の解釈差（M2=30で確定、要ユーザー確認事項として記録）。
