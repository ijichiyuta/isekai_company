# M3 実装計画 v2 — 経済カーブ改訂 × 魂の記憶 × 永続化 × ペイウォール

**日付**: 2026-08-26 / **方式**: Opus並列3体で計画立案→統合(v1)→**Opus並列3体で計画監査**→本v2で是正→実装→再監査（M2と同じゲート）
**v1→v2 の変更理由**: 計画監査（`docs/m3-plan-audit.md`）で **P1の中核前提が数学的・実証的に反証**され、P2/P3にCritical欠陥が判明。ユーザー決定（2026-08-26）を反映し方針を確定した。
**ユーザー決定**: ①**§10.2を改訂**（economyオーバーホールで乗せるのではなく、到達可能カーブへ引き直す） ②**一括M3のまま**（分割しない。ただし監査警告＝スコープ過大・据え置き負債を明示追跡する）。
**前提**: 要件v1.0。要件定義は`docs/requirements.md`（正）。§10.2改訂・economy hash break は ADR-0002 に記録。

## 監査で確定した事実（v1計画の何が間違っていたか）

1. **§10.2 near-geometric は現エンジンでは原理的に到達不能**（監査P1が閉形式＋グリッドで証明）。
   - fame帰還ループの成長比 ρ は**定数**：`ρ = 1 + demandPerFame·price/(100·famePerSalesG)`。
   - §10.2の要求 ρ は区間ごとに**漸減**（100→2000で1.0075、以降1.0050/1.0038/1.0037）。定数ρは漸減ρに構造的一致不能。
   - **設備Lv・品質★はρに効かない**（有限上限の一度きり係数ジャンプ→上限後は必ず線形化）。19,440構成グリッドで±50%内=**0件**。∞容量・∞品質・0コストの上界でも乗らない。
   - → **§10.2を到達可能カーブへ改訂**（ユーザー決定①）。設備Lv/品質★は**終盤の線形頭打ち(-52%)是正＋発明品価値付け**に用いる（従）。
2. **セーブv2のマイグレーション機構が構造不整合**（監査P2 Critical）：現行`saveMigrations`は`state`サブツリーのみ変換。meta は doc トップレベルなので注入不能。機構を**doc全体変換**へ再設計要。
3. **appのセーブ永続化基盤が存在しない**（監査P3 Critical）：`path_provider`もセーブ呼び出しも無く soulPoints は再起動で消える。v1が「app層atomic write既存」と誤認。→ **P0として明示計上**。
4. **ペイウォールtier境界が§8.4と矛盾**（監査P3 Critical）：要件は #16自動発注=**無料** / #15=**完全版** / #3のみ「**自動**」（クリア付与・非課金）。v1は「自動化=有料」と誤読。→ §8.4語彙に正確に合わせる。
5. **canonicalJsonはキーソート済み**（hash.dart:63）→ toJson追記順は非問題（R4(b)は杞憂）。sealed switchはコンパイラ網羅検査→R4(a)はgitマージのみ。

## M3 のゴール（P0基盤＋3本柱、一括）

| ピース | 目的 | 対応AC / 繰越 | 主担当ファイル（排他） |
|---|---|---|---|
| **P0 永続化基盤** | appでセーブを実ディスクに読み書き。これが無いとメタも課金も再起動で消える | AC-15基盤 / C-5 / C-6(tutorial永続化) | `app/pubspec.yaml`(path_provider), `app/game/save_store.dart`(新規), `app/game/game_controller.dart`(load/save配線) |
| **P1 経済カーブ改訂** | §10.2を到達可能カーブへ改訂。設備Lv/品質★で終盤頭打ち是正＋発明品価値 | AC-08 / AC-09 / C-1 / C-2 | `core/engine.dart`, `core/state.dart`(equip/quality), `core/commands.dart`, `assets/balance/economy.json`, headless bots, `gate.dart`, ADR-0002, 要件§10.2改訂 |
| **P2 魂の記憶＋メタ** | 転生をまたぐ恒久成長22項目、soul point消費、2周目短縮、セーブv1→v2 | AC-15 / AC-10再校正 / C-3 / C-6 | `core/meta.dart`(新規), `assets/balance/unlocks.json`(新規), `core/save.dart`(v2機構再設計), `core/state.dart`(fromMeta factory のみ) |
| **P3 ペイウォール** | 無料/有料境界(§8.4正確)、購入導線、復元、動的アンロック数、stub IAP | AC-16 / C-5 | `app/game/entitlements.dart`(新規), `app/game/iap_stub.dart`(新規), `app/ui/shop.dart`+`paywall.dart`(新規), `app/ui/*`(導線) |

**排他所有＋役割分割（監査R4是正）**: state.dart は **toJson/fromJson の新フィールドは P1 のみ**、P2 は `GameState.fromMeta` factory の追加**のみ**（GameStateにmetaを埋め込まない＝MetaStateは別クラス）。commands.dart の新command末尾追記は P1。engine.dart は P1のみ（P2は非編集）。→ 衝突面ゼロ。

---

## P0 — app永続化基盤（監査 Critical-2 の是正、最初に）

現状 `game_controller` の soulPoints/lifeNumber はメモリ上intで再起動消滅。`app/lib/game/game_root.dart:10` 自身が「persist は M3 で配線」と明言。メタ/課金の**土台工事**。

### 実装
- **app/pubspec.yaml**: `path_provider` 追加（ドキュメントディレクトリ取得）。
- **app/game/save_store.dart（新規）**: `encodeSave`/`decodeSave`（core）を実ファイルに橋渡し。
  - **atomic write**: temp ファイルへ書き→`rename`（部分書き込み事故防止、§17.1）。
  - **3世代ローテーション**: `save.0/1/2`。書込は最古を上書き。読込は新しい順に試行し `SaveCorruptException` なら次世代へフォールバック（§16.3/§17.1）。
  - core は dart:io 不可なので **file I/O は app 層に閉じる**（作法遵守）。
- **game_controller**: 起動時ロード、節目（人生終了・転生・アンロック購入・アプリbackground）でセーブ。**tutorial完了フラグ永続化**（C-6：2周目は誘導プリンをスキップ）を meta に含める。

### 完了条件
- アプリ再起動で soulPoints/unlocks/tutorial完了が保持される Widget/統合テスト green。破損セーブ→3世代フォールバック→初期化のテスト。P1の contentHash 変更後は balance_hash mismatch で正当に初期化されることを確認（正常動作）。

---

## P1 — 経済カーブ改訂（§10.2改訂・ユーザー決定①）

### 方針（v1から転換）
**§10.2を到達可能カーブへ改訂するのが主。** 設備Lv/品質★は「§10.2に乗せる魔法」ではなく、**終盤の線形頭打ちを持ち上げ、発明品に継続生産の価値を与える**補助ドライバとして導入する。

### 校正プロセス（推測しない＝M0教訓、trace/gateで実測）
1. **設備Lv・品質★を実装**（下記）。
2. **bin/trace.dart＋--gate で到達可能な定常カーブを実測**（steady/attack/collection に再投資ノブ）。序盤fast→終盤の伸びが設備/品質でどこまで持ち上がるかを実データで見る。
3. **実測できた到達可能な形に §10.2 のチェックポイント目標を引き直す**（ゲーム体験＝「数字が伸び続ける感触」を考慮し、S字の終盤をなだらかな上昇に整える）。要件§10.2の数表を改訂。
4. **AC-09 を改訂カーブで測定**（gate.dart の `_curveTargets` を改訂値へ差し替え）。±50%を改訂カーブに対して判定。
5. **多目的校正（R2）**：AC-07（steady破産<5%/attack破産<30%、hard）を割らず、AC-08（御用達到達）を上げ、AC-10（手動優位）を壊さない点を seed 1/2/999 で探索。fame_per_sales_g 単独変更はAC-10反転（監査実測 +609%→-8%）を招くので**設備/品質/需要を同時に**動かす。

### 変更詳細
- **state.dart**: `int equipmentLevel`(default 0), `int qualityStar`(default 0)。**条件付きtoJson（default時非出力）＋fromJson `?? 0`（監査Critical-2：必須読み禁止）**。events-less byte一致維持。
- **commands.dart**: `UpgradeEquipment()` / `ImproveQuality()`（末尾追記、引数なし＝次段1つ購入、資金不足no-op）。sealed switch はコンパイラが網羅強制。
- **engine.dart**: capacity に `×(100+equipmentLevel×equipStepX100/100)`、sales単価に `×qualityMultX100[qualityStar]/100`。コマンド適用に2ケース（funds減算→Lv/★++、上限チェック）。**追加RNG draw ゼロ・整数固定小数点**。
- **economy.json**（新キー、後方非互換＝ADR-0002）: `equip_cost_base`,`equip_step_x100`,`equip_max_level`,`quality_cost_base`,`quality_mult_x100`(配列),`quality_max_star`,`fame_per_sales_g`(調整)。EconomyDef＋`_rangedInt`バリデーション追記。**上限は実プレイ範囲外**に置き頭打ちを画面外へ（監査P1-5）。
- **C-2（発明品が継続生産で選ばれない）**: 品質★を発明品に優先的に効かせる or 発明品にmargin premium。**選択関数をmargin単独から変える**具体仕様をADRに明記。**完了条件にbot生産ミックスのassert**（発明品が継続生産に選ばれる割合を測定）。
- **headless bots**: BaseBotに再投資ノブ（`reinvestThreshold`等）。idle据え置き（自動化なし下限）。

### ADR-0002（必須）
`docs/adr/0002-economy-curve-revision.md`: 「§10.2 near-geometric は fame律速のρ定数 vs 要求ρ漸減の不一致で到達不能（閉形式証明＋19,440構成グリッド0件＋∞上界でも不可、監査`m3-plan-audit.md`）。よって**§10.2を到達可能な緩和カーブへメジャー改訂**し、AC-09測定ターゲットも差し替える。設備Lv×品質★は終盤頭打ち是正＋発明品価値付けに用いる（§10.2に乗せる主手段ではない）。economy.jsonスキーマ変更で contentHash が変わり M2以前の全セーブを decodeSave が拒否（§2.2 rule7）。ADR-0001『追記のみ原則』のメジャー改訂例外として記録」。改訂前後の§10.2数表を併記。

### 完了条件
全hardゲート（AC-04/05/07）継続PASS。AC-08 は **steady≥80% かつ attack破産<30% を seed 1/2/999 で実測PASSしたときのみ hard化**（未達なら soft継続で正直報告、監査P1-3）。AC-09 worst が**改訂カーブ**に対し±50%内。クロスアーチ hash（--with-events）一致。既存テスト回帰なし＋新テスト。

---

## P2 — 魂の記憶ツリー＋メタ永続化

### データモデル
- **core/meta.dart（新規）**:
  - `class MetaState { int soulPoints; List<int> unlockedIds; List<int> unlockLevels; int lifetimeBest; ... }` — 転生をまたぐ恒久状態。**無限ノード（§8.4 #21/#22の1.6^n）用に `unlockLevels`（id昇順indexで購入回数）を持つ**（監査High-1：Setでは回数表現不能）。toJson/fromJson正準JSON、dart:math/HashMap不可。
  - `class UnlockDef { int id; String name; String desc; int cost; String tier; String modType; int modValue; List<int> requires; bool infinite; }` — unlocks.json由来。
  - **modType**: `start_funds`(+加算), `start_capacity`, `equip_start_level`, `quality_start_star`, `demand_boost_x100`(×), `auto_pricing`(#15), `auto_order`(#16), `lifespan_bonus`, `start_rank`(#3) 等。
- **assets/balance/unlocks.json（新規）**: **要件§8.4の確定表を転記（発明せず single source of truth に従う）＝22項目**。tier は§8.4語彙に正確に：`free`（無料でsoul point購入）/`full`（完全版で解禁）/`auto`（#3のみ・1周目クリアで自動付与・**非課金**）。**#16自動発注=free / #15自動値付け=full**（監査Critical-1）。soul pointコストは§8.4の指数（`1000×1.6^n`）。`requires`で前提ツリー。**contentHashに条件付き算入**（非空時のみ、events同型。空でhash不変の回帰テスト＝監査High-2）。§8.4サマリ行と実表の内部不一致は**要件側を先に確定**してから転記。
- **GameState.fromMeta(balance, seed, meta, {lifeNumber})**: `GameState.initial`を土台に unlock modifier を **id昇順・加算先行→乗算後、無限ノードは購入回数ぶんループ**で適用（監査High-1）。§10.5の1e15天井を出力にclamp。**headlessは`initial`（meta無し）継続、fromMetaはapp限定**。state.dartへのP2の触りは**この factory 追加のみ**（監査R4：toJson/fromJsonはP1のみ）。

### 永続化（セーブ v1→v2、機構再設計＝監査Critical-1）
- **save.dart**: `saveSchemaVersion 1→2`。**マイグレーションチェーンを`state`サブツリー変換→doc全体変換へ再設計**（`saveMigrations[v]`にdoc全体を渡す）。`saveMigrations[1] = (doc) => {...doc, 'meta': _defaultMetaJson()}`。checksum検証はmigrate前の生docに対して（既存順序維持）。`encodeSave(GameState state, MetaState meta, Balance balance)` に拡張、`doc['meta']=meta.toJson()`。`decodeSave` 戻り型を `SaveData(GameState state, MetaState meta)` へ。**既存save_test.dartの全テスト＋`expect(saveMigrations, isEmpty)`（v2で必ず落ちる）を更新対象として明示**。
- **R3決着＝選択肢A（監査P2）**: **リリース前（M3=2027-02、公開4月）なので救うべき実v1セーブは存在しない**。よって「v1→v2マイグレーションは**機構検証に格下げ**、economy hash変更でv1は正当破棄」を ADR-0002/計画に明記。**AC-15は balance_hash を揃えた合成テストで『マイグレーション機構が動く』ことを検証**（実運用の旧セーブ救済ではない、と honest に位置づけ）。
- **game_controller**: `MetaState _meta` 保持。`rebirth()` で soulPoints統合＋`GameState.fromMeta(...)`。`purchaseUnlock(int id)`（soul point消費）。P0の save_store 経由で永続化。

### AC-10 再校正（監査High-4／C-3、"据え置き可"を撤回）
#15/#16 modifier を入れると放置botの利益率が上がり手動優位が縮む。**P2完了条件に「headless idle/collection に自動値付け・自動発注ノブを追加し、gate.dart AC-10（attack vs idle rev/wk）を再測定、+10..20%へ寄せる校正を1イテレーション」を必須化**（測って正直報告、hard化は次段）。

### MetaReader インターフェース（P3疎結合）
```dart
abstract class MetaReader {
  int get soulPoints;                    // §8.4「未使用pt」
  bool isUnlocked(int id);
  int unlockLevel(int id);               // 無限ノードの現在段（監査Low-1）
  Iterable<UnlockDef> get allUnlocks;
  Iterable<UnlockDef> unlocksOfTier(String tier);
}
```

### 決定論・境界の縛り（監査High-3/R6）
- **加算×乗算を交錯させたフィクスチャで id昇順・加算先行の適用結果を golden 値固定**（順序依存を炙り出す）。
- **check_forbidden.sh に meta.dart を対象追加**（double/dart:math不在）＋**`packages/headless`配下で`fromMeta(`参照をfail**（R6をCIで縛る、監査Medium-2）。

### 完了条件
22項目ツリーがロード・検証・購入・適用でき2周目短縮を headless で実証。セーブv1→v2 round-trip（AC-15合成テスト）green。fromMeta適用済みstateのreplay bit一致。events-less/meta-less byte一致不変。unlocks空でcontentHash不変。

---

## P3 — ペイウォール＋IAP境界（§8.4に正確に）

### 機能境界（監査Critical-1 是正）
- **unlocks.json の tier = §8.4語彙**：`free`（無料soul point購入）/`full`（完全版で解禁）/`auto`（#3・クリア付与・非課金）。
- **app/game/entitlements.dart（新規）**: `class Entitlements { bool get isFull; bool canUnlock(UnlockDef); }`。**ゲート対象は `full` tier のみ**。`auto`(#3)はクリア条件で付与＝課金無関係。`free`は常時可。**#16自動発注はfree（isFull不要）、#15はfull**。「自動化=有料」の束ねを廃止。
- **UnlockSummary.compute(MetaReader, Entitlements)**: **AC-16** — 「あと何個で全解放」を unlocks.json から動的算出（ハードコード禁止）。**AC-16テストは unlocks.json を改変した合成balanceで compute 出力が追従することを検証**（固定期待値でなく実カウント一致、監査Medium-1）。

### 導線＋復元（監査Critical-3 是正）
1. 魂の記憶ツリー：`full`項目に鍵＋「フル版で解放」。
2. 転生バナー：2周目・非破産で初回ペイウォール（メイン導線）。
3. **ショップ画面(#18、新規`app/ui/shop.dart`)**：フル版案内＋**復元ボタン常設**（App Store 3.1.1／§14.4）。
4. 設定画面：**復元ボタン常設**（ショップ＋設定の2箇所、§12.2）。
5. `full` 機能タップ時：未購入なら paywall。
- **app/ui/paywall.dart（新規）**: 価格・特典・購入/復元。UnlockSummaryで「今フル版で+N個解放」を動的表示。

### stub IAP（RevenueCatはM4、監査High-1 是正）
- **app/game/iap_stub.dart（新規）**: `abstract class IapClient { Future<bool> purchaseFull(); Future<bool> restore(); }` ＋ `StubIapClient`。**`kReleaseMode`分岐：release=「準備中」表示＋購入ボタン無効化（グレーアウト）、debug=即成功**。M4で`RevenueCatIapClient`差し替え。**M3のrelease buildは審査に出さない（ADR明記）**。AC-14 CIに「stub即成功パスがreleaseに混入しない」検証を追加。
- **entitlements永続化（監査High-2 是正）**: **balance_hash非依存の別ファイル**に保存（economy改訂で課金実績が消える経路を断つ）。meta セーブに相乗りさせない。M4でRevenueCatが権威になったらローカルは機内モード用キャッシュに降格。

### 完了条件
5導線が表示・遷移。UnlockSummaryがbalance変更に追従（AC-16動的）。stub購入でfull項目解禁するe2e（Widgetテスト）green。無料版で`full`が購入不可、`free`(#16含む)は購入可であること。復元ボタンがショップ＋設定に常設。

---

## 統合順序と依存

```
P0 永続化基盤 ──→ P1 経済改訂 ──→ P2 メタ(fromMetaはP1のequip/quality初期値に効く) ──→ P3 ペイウォール(tierゲート)
                     │                        │                                            │
                ADR-0002/§10.2改訂       MetaReader契約 ←──────────────────────────────────┘（読むだけ）
```
1. **P0を最初に**：セーブが実ディスクに乗らないとメタも課金も無意味（監査Critical-2）。
2. **P1**：§10.2改訂＋設備/品質。contentHash・stateスキーマが変わる基盤。
3. **P2**：unlockをinitial stateへのmodifierとして被せる。engine本体は不変。
4. **P3**：tierゲートのみ。MetaReader/Entitlements契約でP2と疎結合、UI層に閉じる。

**並列可能**: P3のUI（shop/paywallモック）は MetaReader契約が固定済みなら**モックに対してP1/P2と並行先行可**。engine実効果配線のみ直列（P1→P2）。gitマージは P1→P2→P3 の順（監査R4分担案）。

## リスクと対応（監査を反映）
- **R1（旧最重要）解消**: §10.2改訂で「乗らない」問題を回避（ユーザー決定①）。ADR-0002に不到達証明を記録。
- **R2**: economy改訂でattack破産跳ね・AC-10反転。→ 設備/品質/需要/fameを同時に動かす多目的校正、seed 1/2/999 全通し、trace実測。
- **R3 決着**: 選択肢A（マイグレーションは機構検証に格下げ、v1は正当破棄）。合成テストでAC-15。
- **R4 非問題化**: canonicalJsonソート＋役割分割（state.dartのtoJsonはP1のみ、P2はfromMeta factoryのみ）で衝突面ゼロ。
- **R5**: 適用順golden test（加算×乗算交錯）で固定。
- **R6**: check_forbidden.shで headless の fromMeta 参照をCI fail。
- **R7（新・スコープ）**: 一括M3は週20hに対し過大と監査警告（ユーザーは一括を選択）。→ **据え置き負債を明示追跡**（下表）。P0→P1→P2→P3の内部チェックポイントで各ゲートを緑にしてから次へ。燃え尽き対策として§10.2改訂のフォールバックを先に用意した状態で校正に入る。

## M2繰越 C-1〜C-7 の対応表（監査の網羅チェックを反映）
| # | 項目 | M3での解決 |
|---|---|---|
| C-1 | AC-08・経済カーブ破綻 | **P1**（§10.2改訂＋設備/品質＋AC-08条件付きhard化＋ADR-0002） |
| C-2 | 発明品が継続生産で選ばれない | **P1**（品質★/margin premium＋**生産ミックス測定を完了条件に**） |
| C-3 | AC-10手動優位（#15/#16後再校正） | **P2**（"据え置き可"撤回、**再測定を必須化**） |
| C-4 | AC-06 実機1周60分実測 | **M3後半/M4冒頭に先送りと明記**（経済改訂前の実測は破棄対象ゆえ意図的先送り） |
| C-5 | AC-15マイグレーション | **P0（永続化基盤）＋P2（v2機構＋合成テスト）** |
| C-6 | 魂の記憶22項目＋メタ永続化＋tutorial永続化 | **P0（tutorial永続化）＋P2（ツリー本体）** |
| C-7 | §10.1粗利逸脱・実アセット量産・スコアε | **一部P1（品質★が粗利に効く）／アセット・εは明示据え置き（M4以降）** |

## 検証（M2同様）
- `cd packages/headless && dart run bin/run.dart --gate --with-events`（hard全PASS、AC-09は改訂カーブ）
- `--verify-replay`（events込み・fromMeta済み両方）決定論一致
- クロスアーチ hash 照合（ubuntu×macos）継続一致
- core/headless/app 全テスト＋新規テスト green、`tool/check_forbidden.sh` PASS（meta.dart対象・headless fromMeta禁止）
- app再起動で永続化保持、3世代フォールバック
- 節目で **memory更新＋commit＋push**（[[memory-upkeep-preference]]）
