# M3 実装計画 — 経済カーブ再建 × 魂の記憶 × ペイウォール

**日付**: 2026-08-26 / **方式**: Opus並列3体で計画立案 → 本書で統合 → 監査 → 実装 → 再監査（M2と同じゲート）
**前提**: M2再監査の繰越（docs/m2-audit.md の C-1/C-5/C-6/C-3）を潰す。§番号は要件定義v1.0。

## M3 のゴール（3本柱）

| ピース | 目的 | 対応AC / 繰越 | 主担当ファイル（排他） |
|---|---|---|---|
| **P1 経済カーブ再建** | 容量律速の線形経済 → §10.2 near-geometric に一致させる。第2収益ドライバ（設備Lv=容量倍率 + 品質★=単価倍率）と fame 減速で複利再投資ループを作る | AC-08 / AC-09 / C-1 / C-2 | `core/engine.dart`(sales/cost節), `core/state.dart`(新フィールド), `core/commands.dart`, `assets/balance/economy.json`, headless bots, `gate.dart`(AC-08判定), ADR-0002 |
| **P2 魂の記憶ツリー＋メタ永続化** | 転生をまたぐ恒久成長。22項目のアンロック、soul point 消費、2周目短縮、セーブ v1→v2 | AC-15 / C-6 | `core/meta.dart`(新規), `assets/balance/unlocks.json`(新規), `core/save.dart`(v2), `core/state.dart`(fromMeta), `app/game_controller.dart`(meta配線) |
| **P3 ペイウォール＋IAP境界** | 無料/有料の機能境界、購入導線、動的アンロック数表示。RevenueCat本体はM4、M3はstub IAP | AC-16 / C-5 | `app/game/entitlements.dart`(新規), `app/game/iap_stub.dart`(新規), `app/ui/paywall.dart`(新規), `app/ui/*`(導線4箇所), unlocks.json の tier フラグ |

**排他所有の原則**: P1 は core のシミュレーション（engine/economy）、P2 は core のメタ層（meta/save/unlocks）、P3 は app のUI/課金層。core の共有ファイル（state.dart, commands.dart）は P1 が economy 系フィールド、P2 が meta 系フィールドを**別ブロックで追記**。衝突面はインターフェース契約（後述）で事前に固定。

---

## P1 — 経済カーブ再建（最重要・基盤）

### 問題の再確認（実データ）
現状 `pool = (baseDemand + fame×demandPerFame)/100`、`revenue = Σ soldUnits × 固定basePrice`、`capacity = base + employees×artisanOutput`（従業員上限30 → 実効上限 ~302単位/週）。
- fame は `revenue/famePerSalesG(=20)` で毎週増加 → 序盤に demand が暴走（AC-09 で +25637%）
- 単価も容量も**上限固定** → 終盤は線形頭打ち（-52%）
- §10.2 目標 funds＝400/1000/1800/2600tick で 2000/40000/800000/15000000（≒×20,×20,×18.75 の near-geometric）
- 線形経済では原理的に到達不能（AC-08 御用達到達 0%）

### 解決策：複利再投資の2ドライバ
| ドライバ | 効果 | 実装 | 上限 |
|---|---|---|---|
| **設備レベル** `equipmentLevel` | 週次生産容量を倍率 ×(100+Lv×step)/100 で拡大 | 新Command `UpgradeEquipment`、コストは `equip_cost_base × 倍率^Lv`（整数近似 x100） | 例 Lv20 |
| **品質★** `qualityStar` | 販売単価を ×[100,130,170,220,...]/100（★段階）で拡大＝§10.1 粗利レンジ内 | 新Command `ImproveQuality`、コストは `quality_cost_base × 段階倍率` | 例 ★5 |

**なぜ複利になるか**: funds を設備/品質に再投資 → 容量×単価が同時に伸びる → revenue が幾何級数的に伸びる → さらに再投資。fame は demand の緩やかなブースト役に降格（`fame_per_sales_g` を 20→3000〜4000 に上げて暴走を止める）。設備と品質の cost 曲線を幾何にすることで「稼ぎ→投資→次段解禁」のテンポが §10.2 の各チェックポイントに乗る。

### 変更詳細
- **state.dart**: `int equipmentLevel`(default 0), `int qualityStar`(default 0) を追加。**条件付きtoJson**（default時は非出力）で events-less の byte 一致は維持しつつ、economy.json のハッシュ変更で旧セーブは弾かれる（ADR-0002）。
- **commands.dart**: `UpgradeEquipment()` / `ImproveQuality()`（引数なし＝次段を1つ購入、資金不足なら no-op）。sealed class の switch 網羅を維持。
- **engine.dart**:
  - capacity 計算に `× (100 + equipmentLevel×equipStepX100/100)` を乗算（整数）。
  - sales の revenue 加算で `basePrice × qualityMultX100[qualityStar] / 100` を単価に。
  - コマンド適用節に2ケース追加（funds 減算 → Lv/★ インクリメント、上限チェック）。
  - **決定論**: 追加のRNG draw なし。全て整数固定小数点。
- **economy.json**（新キー、後方非互換＝ADR-0002）: `equip_cost_base`, `equip_step_x100`, `equip_max_level`, `quality_cost_base`, `quality_mult_x100`(配列), `quality_max_star`, `fame_per_sales_g`(20→調整値)。balance.dart の EconomyDef と _rangedInt バリデーション追記。
- **headless bots**: steady/attack/collection に「利益率を見て設備/品質へ再投資する」ノブを追加（BaseBot テンプレートに `reinvestThreshold` 等）。idle は据え置き（自動化なしの下限）。**bin/trace.dart で週次トレースを見ながら実データで校正**（推測しない＝M0の教訓）。
- **gate.dart AC-08 を hard 化の条件付き判定に**: steady 御用達到達 ≥80% **かつ** attack 破産 <30% を seed 1/2/999 で満たしたら hard、未達なら soft で正直に乖離報告（AC-09 と併記）。C-2（発明品が継続生産で選ばれない）は品質★が発明品に効くよう重み付けし、band/粗利で発明が選ばれる配分に。

### ADR-0002（必須）
`docs/adr/0002-economy-overhaul-hash-break.md`: 「§10.2 near-geometric を満たすため容量律速の線形経済を破棄し、設備Lv×品質★の複利再投資モデルへ移行。economy.json スキーマ変更で contentHash が変わり、M2以前の全セーブを decodeSave が拒否（§2.2 rule7）。ADR-0001の『balance追記のみ原則』の例外＝**メジャー改訂**として明示記録」。§10.2 改訂案（カーブ側を緩める）は不採用理由も併記。

### 完了条件
- 全hardゲート（AC-04/05/07）継続PASS、AC-08 が steady≥80%、AC-09 worst が ±50% 内、AC-10 は P2/#15/#16 後に再校正（据え置き可）。
- クロスアーチ hash 照合（events込み `--with-events`）継続一致。既存98テスト回帰なし＋新テスト（設備/品質/再投資曲線/EconomyDef バリデーション）。

---

## P2 — 魂の記憶ツリー＋メタ永続化

### データモデル
- **core/meta.dart（新規）**:
  - `class MetaState { int soulPoints; List<int> unlockedIds; int lifetimeBest; ... }` — 転生をまたぐ恒久状態。toJson/fromJson（正準JSON、決定論作法遵守＝dart:math/HashMap不可）。
  - `class UnlockDef { int id; String name; String desc; int cost; String tier(free/full/auto); String modType; int modValue; List<int> requires; }` — unlocks.json から。
  - **modType**: `start_funds`(+加算), `start_capacity`, `equip_start_level`, `quality_start_star`, `demand_boost_x100`, `auto_pricing`(#15), `auto_order`(#16), `lifespan_bonus` 等。**適用順は「加算→乗算、id昇順」で決定論固定**。
- **assets/balance/unlocks.json（新規）**: 24項目（free=12 / full=10 / auto=2）。`requires` で前提ツリー。soul point コストは §8.4 の指数曲線。**contentHash に算入**（events同様、balance.dart で unlocks を hashInput に追加。ただし空/非存在時は従来ハッシュ維持の条件付き算入）。
- **GameState.fromMeta(balance, seed, meta, {lifeNumber})**: `GameState.initial` を土台に、unlocked な UnlockDef の modifier を id 昇順で適用（start_funds加算 → capacity/equip/quality の初期値底上げ）。**headless は `initial`（meta無し）を使い続けるので byte 一致不変**。app のみ `fromMeta`。

### 永続化（セーブ v1→v2）
- **save.dart**: `saveSchemaVersion 1→2`。セーブ doc に `'meta'` セクション追加（`state`＝現在の生涯、`meta`＝恒久）。`encodeSave(state, meta, balance)` にシグネチャ拡張。`saveMigrations[1]` を実装（v1 の state-only doc に **default meta を注入**＝soulPoints 0/unlocked 空）。**AC-15**: v1→v2 マイグレーションテスト（旧セーブ読込→meta既定付与→再エンコードで round-trip）。
  - 注意：P1 の economy 改訂で contentHash が変わるため、実運用では balance_hash mismatch が先に効いて旧セーブは弾かれる。マイグレーションの健全性は**balance_hash を揃えた合成テスト**で検証（監査確認事項）。
- **app/game_controller.dart**: `MetaState _meta` を保持。`rebirth()` で `soulPointsTotal` を `_meta.soulPoints` に統合し、`GameState.fromMeta(...)` で新生涯を開始。soul point 消費でアンロック購入する `purchaseUnlock(int id)` を追加。セーブ/ロード配線（app層の atomic write は既存）。

### MetaReader インターフェース（P3 とのデカップリング）
```dart
abstract class MetaReader {
  int get soulPoints;
  bool isUnlocked(int id);
  Iterable<UnlockDef> get allUnlocks;      // balance 由来
  Iterable<UnlockDef> unlocksOfTier(String tier);
}
```
`MetaState`（+balance）が実装。P3 はこの読み取り契約のみに依存し、P2 の内部表現を知らない。

### 完了条件
- 22+項目のツリーがロード・検証・購入・適用でき、2周目が短縮（start ボーナスで序盤 tick 数減）を headless で実証。
- セーブ v1→v2 round-trip（AC-15）green。core 決定論テスト（fromMeta 適用済み state の replay bit 一致）green。events-less/meta-less の byte 一致不変。

---

## P3 — ペイウォール＋IAP境界

### 機能境界（無料/有料）
- **unlocks.json の tier** で決定：`free`=無料で soul point 購入可、`full`=フルアン（有料）購入で解禁、`auto`=#15自動値付け/#16自動発注（有料寄り＝AC-10 の自動化）。
- **app/game/entitlements.dart（新規）**: `class Entitlements { bool get isFull; bool canUnlock(UnlockDef); }` — 購入状態を保持。`full`/`auto` tier は isFull が真のときのみ購入可。free tier は常に可。
- **UnlockSummary.compute(MetaReader, Entitlements)**: **AC-16** — 「あと何個で全解放」を balance から動的計算（ハードコード禁止）。無料で解放済/可能な数、有料限定数、合計を返す。tier 別カウントは unlocks.json 由来。

### 導線（4タッチポイント）
1. 魂の記憶ツリー画面：`full`/`auto` 項目に鍵アイコン＋「フル版で解放」。
2. 転生バナー（`_LifeEndBanner`）：2周目・非破産で初回ペイウォール（#3 メイン導線）。
3. 設定/情報画面：復元購入・フル版案内。
4. `auto` 機能（自動値付け/発注）タップ時：未購入なら paywall。
- **app/ui/paywall.dart（新規）**: 価格・特典・購入/復元ボタン。UnlockSummary で「今フル版にすると +N 個解放」を動的表示。

### stub IAP（RevenueCat は M4）
- **app/game/iap_stub.dart（新規）**: `abstract class IapClient { Future<bool> purchaseFull(); Future<bool> restore(); }` ＋ `StubIapClient`（デバッグは即成功、release は「準備中」表示 or 常に false）。M4 で `RevenueCatIapClient` を差し替え。Entitlements の永続化は meta セーブに `entitlements` セクションで相乗り（または別ファイル＝監査で判断）。

### 完了条件
- 4導線が表示・遷移し、UnlockSummary が balance 変更に追従（AC-16 動的）。stub 購入でフル項目が解禁される e2e（Widgetテスト）green。無料版で `full`/`auto` が購入不可であること。

---

## 統合順序と依存

```
P1 (economy 基盤) ──→ P2 (unlock modifier は P1 の equip/quality 初期値に効く) ──→ P3 (Entitlements が P2 の tier をゲート)
        │                        │                                                    │
   ADR-0002                MetaReader 契約 ←──────────────────────────────────────────┘（P3 は読むだけ）
```
1. **P1 を先に**：economy 改訂で contentHash と state スキーマが変わる基盤。ここが固まらないと P2 の fromMeta modifier（equip/quality 底上げ）が定義できない。
2. **P2 を層として被せる**：unlock を initial state への modifier として適用。P1 の Command/フィールドに依存するが engine 本体は変えない。
3. **P3 は tier ゲートのみ**：MetaReader/Entitlements 契約で P2 と疎結合。UI 層に閉じる。

**並列可能な部分**: P1 の economy 校正（headless）と P2 の unlocks.json 設計・meta.dart 骨組み・P3 の paywall UI モックは、インターフェース契約が固定済みなら並行実装可。engine への実効果配線は P1→P2 の順で直列。

## リスクと監査で潰す点
- **R1（最重要）**: 複利2ドライバでも §10.2 に乗らない可能性。→ 監査で「設備×品質の cost/効果曲線が本当に near-geometric を生むか」を数式・実走で裏取り。乗らなければ §10.2 改訂（カーブ緩和）へフォールバック（ADR-0002 に両論）。
- **R2**: economy 改訂で attack bot 破産率が跳ねる（M2で artisan=16 → 98%破産の再来）。→ AC-07 hard を守りつつ AC-08 を満たす multi-objective 校正。seed 1/2/999 全通し。
- **R3**: セーブ v2 マイグレーションが balance_hash mismatch に隠れて未検証になる。→ balance_hash を揃えた合成テストで AC-15 を独立検証。
- **R4**: state.dart / commands.dart の共有編集で P1・P2 が衝突。→ フィールド/ケースを別ブロック追記、条件付きtoJson の順序固定。
- **R5**: unlock modifier 適用順が非決定的だと replay が壊れる。→ id 昇順・加算先/乗算後を厳守、テストで固定。
- **R6**: fromMeta で meta-affected state を headless が使うと determinism CI が割れる。→ headless は initial のみ、fromMeta は app 限定を徹底（監査で境界確認）。

## 検証（M2と同様）
- `cd packages/headless && dart run bin/run.dart --gate --with-events`（hard 全PASS）
- `--verify-replay`（events込み・fromMeta 済み両方）決定論一致
- クロスアーチ hash 照合（ubuntu×macos）継続一致
- core/headless/app 全テスト＋新規テスト green、`tool/check_forbidden.sh` PASS
- 節目で **memory 更新＋commit＋push**（[[memory-upkeep-preference]]）
