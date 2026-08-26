# 開発ログ

## M0：技術基盤（2026-08-25 着手）

**目標（要件 §24 / 付録A）**: シード指定で1周ヘッドレス完走・両アーキでリプレイ一致・1,000周15分以内。

### 実装済み

```
packages/core/            pure Dart・決定論コア（Flutter/IO/double/DateTime/HashMap 不使用）
  lib/src/hash.dart       FNV-1a 64bit ＋ 正準JSON（状態ハッシュ・セーブchecksum・balanceハッシュ）
  lib/src/money.dart      固定小数点ヘルパ（bp / x100、浮動小数点なし）
  lib/src/rng.dart        PCG32 自前実装・システム別ストリーム（economy/discovery/events/employees）＋消費カウンタ永続化
  lib/src/balance.dart    JSONローダ＋スキーマ検証＋balanceコンテンツハッシュ
  lib/src/commands.dart   Command（Order/Develop/Produce/Hire/Grant）。外部流入はGrant経由に一本化
  lib/src/state.dart      GameState（全状態＋RNG状態）。List indexed（HashMap不使用）。stateHash()
  lib/src/engine.dart     tick(): コマンド適用→販売→週次コスト→破産判定→昇格→時間進行
  lib/src/save.dart       encode/decode（正準JSON＋checksum＋schema_version＋balance_hash検証）
packages/headless/        オートプレイ・統計
  lib/src/steady_bot.dart 堅実型ボット（ステートレス＝save/load耐性あり）
  lib/src/runner.dart     runLife / verifyReplay（チェックポイント照合）
  bin/run.dart            ランナー（--lives --seed --verify-replay --csv --hash-only）
  bin/trace.dart          単一人生の週次トレース（デバッグ）
assets/balance/           economy/materials/recipes/ranks.json（要件v1.0の初期値を転記。11レシピの縮小版）
tool/check_forbidden.sh   §2.2禁止則の静的検査
.github/workflows/ci.yml  両アーキtest＋禁止則＋200周スモーク＋クロスアーチhash照合＋夜間1万周
```

### 検証結果（2026-08-25）

| 受け入れ条件 | 結果 |
|---|---|
| AC-01 完走率100%・クラッシュゼロ | ✅ 破産0/1000 |
| AC-02 リプレイ決定論（同一シード2回一致） | ✅ verifyReplay OK・save/load中断再開もbit一致 |
| AC-03 1ティックp95≦1ms／1,000周≦15分 | ✅ 0.3µs/tick・1,000周0.8秒 |
| AC-14 本番にデバッグ非含有 | ⏳ デバッグメニューはM1のFlutter層で実装時にビルドフレーバー分離 |
| AC-15 セーブマイグレーション | ⏳ v1のみ。schema_version基盤は実装済み（不一致で拒否） |
| 決定論禁止則 lint | ✅ check_forbidden.sh クリーン |

**ボット調整メモ**: 初期ボットは①生産capacityを発見数で割り算しplan=0で餓死、②発見前に雇用して資金枯渇、の2バグで100%破産していた。トレース駆動で特定し、生産は需要推定に基づく整数配分・雇用は「発見済み商品がある時のみ」に修正。結果 破産0%・中央値資産194万G・到達ランク商会(3)。御用達到達80%(AC-08)はM2（75種フルレシピ＋需要曲線・季節・品質・従業員Lv）の課題。

### 現バランスの既知の縮小点（M2で拡張）

- レシピ11種（本番75種）・素材8種（本番32種）・製法8種は定義のみ
- 需要モデルは `base + fame×係数` の線形＋±5%ジッターのみ（季節・流行・購買応答曲線は未実装）
- 従業員はLv・種族・性格・離職なし（頭数×固定産出のみ）
- 名声は販売額ベースのみ（発明・イベント・昇格ボーナスは実装済みだがイベント未実装）
- 大陸商会ランクは enabled:false（v1.0）

### M0 ハードニング（並列専門家レビュー反映・2026-08-26）

Opus 4.8 の並列エージェント3体（決定論/数値・セーブ整合性・エンジン論理）でコアを敵対的レビュー。1体は PCG32 を24万ドローで参照実装と照合、1体は約95週目の int64 オーバーフロー発火を特定。発見した実バグを修正:

| 重大度 | 発見 | 修正 |
|---|---|---|
| Critical | `money.dart` の `value*bp` が割り算前に int64 オーバーフロー→税額が負に化ける | 打ち切り除算で乗算分割（`remainder`使用で負値もゼロ方向丸め維持）＋入力を1e15クランプ |
| Critical | §10.5 の1e15上限クランプがエンジンに皆無→fame→demand→revenueの複利で桁膨張 | `clampCap` を fame/totalRevenue/funds に適用。demandはfame経由で連動収束 |
| Critical | セーブ checksum が schema_version/balance_hash を保護外・`decodeSave`が生TypeErrorを漏らす・マイグレーション枠なし | checksum をドキュメント全体に拡大／全例外を `SaveCorruptException` に正規化／`saveMigrations` チェーンの器を導入（AC-15） |
| High | `nextInt(0)` がRNG消費後にクラッシュ→リプレイずれの時限爆弾 | ドロー前に `bound<=0` を弾く |
| High | `toJson` が可変Listを共有参照→スナップショット汚染（§17.1の時限爆弾） | `List.of` で防御的コピー |
| High | balanceローダが String/bool 欠損で生例外・空配列/重複レシピ未検査 | `_reqStr`/`_reqBool`＋空配列・重複combo・負値・名声/資産単調性を検証 |

検証: 全30テスト（core 26＋headless 6）通過。バランスハッシュ・1000周中央値・リプレイが修正前と完全一致＝**正常系を保ったまま穴だけ閉塞**。オーバーフロー修正は money_test・engine_test で境界値を直接実証。

**繰り越し（accepted risk / 仕様確認）**:
- 需要モデルが「全商品共通1変数×商品数」で疑似無限需要（High）→ M2で共有プール配分or商品別需要へ（コード内コメントで明示済み。上限クランプで当面のオーバーフローは断った）
- 昇格判定が週次コスト控除後の funds を参照＝閾値ちょうどで1週遅延（Medium）→ 「資産」の精算前/後定義を要件で確定（未決）
- 寿命tickでの昇格可否（Medium）→ 生涯スコアδ項の再現性のため仕様固定（未決）
- 攻め型/放置型/回収型ボット未実装 → AC-09/10 検証に必要、M2前半で追加
- dart2js（Web）はintがdoubleになり全ハッシュ/RNG破綻 → コアは非Webにピン留め。check_forbidden.sh が dart:html を既に禁止。ADR-1に「Web禁止」を明記予定

### 検証基盤の拡張：需要モデル是正＋4ボット（2026-08-26）

M1着手前に、繰り越していた検証基盤を抜け漏れなく厚くした。

**需要モデル是正（High指摘の解消）**: 「全商品共通1変数×商品数」の疑似無限需要を、**共有需要プール**に変更（`engine.dart`）。総販売がプール上限で頭打ちになり、商品数を増やしても需要が線形に増えない。RNGドロー数はティックあたり一定（jitter1回）を維持＝決定論不変。プール配分は現状id順、価格/季節/流行の重み付けはM2。

**4ボット完備（§18.1）**: `BaseBot`（テンプレート＋調整ノブ）を基底に4種を実装。
| ボット | 方針 | 200周実測（seed1〜200） |
|---|---|---|
| steady 堅実型 | 均衡（基準） | 破産0% / 中央1.92M / rank3.00 |
| attack 攻め型 | 薄い資金・積極拡大 | 破産11% / 中央1.92M / rank2.67 |
| idle 放置型 | 最小操作・大きな現金留保 | 破産0%（床保証）/ 中央319K / rank2.00 |
| collection 回収型 | 能動＋オフライン収益（Grant経由） | 破産0% / 中央1.99M / rank3.00 |

- 全4ボットで決定論（AC-02）と完走（AC-01）を確認。save/load中断再開のbit一致も攻め型で検証
- `bin/run.dart --compare` で4ボット横並び＋**AC-10読み値**（攻め型 vs 放置型の週次収益比）を出力
- 回収型のオフライン注入は §17.2 の式（週次純利益×8週×20%、上限=次ランク資産×10%）を状態の純関数として実装＝決定論維持。推定スループットは capacity 上限でクランプ（プール過大計上を回避）

**繰り越し（M2校正）**: AC-10読み値は現状+548%（目標+10〜20%）。放置型が頼る自動化（自動発注#16・自動値付け#15）が未実装のため。**計測インフラは完成、校正はM2**。§18.1の受け入れ条件AC-07/09/10がこれで計測可能になった。

テスト: core 27＋headless 14＝41通過。バランスハッシュ不変（JSON未変更）。

### M0 監査ゲート（M1着手前・2026-08-26）

Opus 4.8 の並列エージェント3体（コア数値・セーブ整合性・ボット/ゲート判定）で M0 を監査。全エージェントが実際に dart test / headless を走らせて裏取り。**総合判定 GO**（AC-01/02/03 実測PASS、AC-14/15/17 は対象機能未存在で N/A・M1宿題として明記済み）。ただしGO前提として土台の穴を指摘され、以下を修正:

| 重大度 | 監査指摘 | 修正 |
|---|---|---|
| High | `balance.dart` が malformed JSON（methods欠損・entry非Map・method非String）で生TypeErrorを漏らす | `fromJsonMaps` を try/catch で `BalanceException` に正規化＋`_reqList`/`_reqMap`/`_reqStr` で全cast置換 |
| High | `.cast<String>()` の遅延評価穴（`['cooling',42]` が無検証で通る） | methods を要素検証しつつ即時実体化 |
| High | fame の invention 加算・rank-up 加算が clampCap 外（累積量±cap不変条件が fame で破れ、balance変更一発で int64 wrap 余地） | engine.dart の両箇所を `clampCap` 経由に |
| Medium | economy/rank の負値・上限無検証（start_funds<0, lifespan<0, tax_bp>100%, 負賃金…） | `_rangedInt`（既定[0,1e15]、除数min1・倍率上限・tax上限100%）で全数値を範囲検証 |

検証: core 40＋headless 14＝54テスト通過（malformed入力→BalanceExceptionの新規テスト群を追加）。バランスハッシュ・4ボット実測値は修正前と完全一致＝挙動不変で穴のみ閉塞。

**監査で GO に付された追認事項（M1で対応）**:
- **AC-02 クロスアーチ**: 監査はARM64単独。x64一致は CI（ubuntu×macos の hash diff ジョブ）の緑を確認して初めて完全PASS。次回CI実行で要確認
- **balance_hash ↔ セーブ互換の密結合（P3）**: M2で recipes 11→75 に拡張すると既存セーブが balance_hash 不一致で全滅。ADR-6（balance変更は転生境界のみ）で吸収するか schema移行と分離するかを M1 で ADR 化
- **AC-14**（デバッグメニュー本番除外）・**AC-17**（量子化パイプライン＋アセットCI）は M1 実装物
- オフラインGrantの上限クランプは現バランスで未発火（休眠中・コードは正）。M2の桁で再実測

## M1：第1層 vertical slice（2026-08-26 着手）

**目標（要件 §24）**: 触って15分遊べる第1層ループ＋プリン発明演出＋主要4画面＋デバッグメニュー。

### 実装済み（app パッケージ）

```
app/  Flutter（isekai_core 依存、Riverpod、ios/macos プラットフォーム）
  lib/game/
    format.dart          K/M/B/T表記（整数演算）＋年季週カレンダー
    tick_clock.dart      TickClock抽象（Real / Fake）＝テスト用に手動ステップ可能
    game_controller.dart 決定論コアをラップ。予約制コマンド＋速度/ポーズ＋発明イベント検出＋自動ポーズ。デバッグ操作(kDebugMode)
    balance_loader.dart  rootBundle から balance JSON をロード（app が IO 境界）
    providers.dart       Riverpod: balance(Future) / tickClock / gameController(ChangeNotifier)
  lib/ui/
    app.dart             ブートストラップ（balanceロード待ち→MainScreen）
    main_screen.dart     HUD（資金/名声/年季週）＋次ランクバー＋店舗ビュー＋速度バー（右下）＋5ボタンナビ＋ボトルネックバッジ＋人生終了バナー
    develop_screen.dart  PB開発（素材2枠＋製法1）＋発見済みレシピ一覧。発明時は自動で戻り演出表示
    invention_overlay.dart 発明演出（§12.5、フラッシュ＋スケールイン＋ボーナス表示）
    order_screen / production_screen / sales_screen  発注・生産・販売（自動）
  lib/debug/debug_menu.dart  資金付与・時間加速・全解放（kDebugModeゲート→release時tree-shakeでAC-14）
  test/  game_controller / widget（発明演出まで） / format = 9テスト
```

- **決定論コアはそのまま利用**（app は UI・タイマー・演出の表示層に徹する＝要件§2.2の分離を実装で維持）
- 予約制（§2.1）: UI操作は次ティックに反映。管理画面を開くと自動ポーズ（§12.1）
- プリン発明の全経路（発注→開発→発明演出→取得）を widget テストで検証
- **AC-14**: デバッグメニューは `if (kDebugMode)` 越しにのみ到達＝release で dead-code 除去。ADR化とビルドフレーバーの厳密分離は残タスク

### 検証（2026-08-26）

- app: `flutter analyze` クリーン、`flutter test` 9通過（core40＋headless14＋app9＝63）
- CI に flutter ジョブ追加（analyze＋test＋balance コピー同期チェック）
- `flutter run` での実機/シミュレータ確認は未実施（このヘッドレス環境では不可。iOS実機確認はTestFlight前に別途）

### M1 残タスク

- オンボーディング90秒台本（§13：前世カットイン→転生→誘導発注→プリン発明→初売上）
- アートバイブル確定（/art-bible）＋AI生成→量子化パイプライン＋量産テスト（AC-17、/game-visual-qa ゲート）
- デバッグメニューのビルドフレーバー厳密分離＋CI検査（AC-14の完全化）
- balance_hash↔セーブ互換の密結合を ADR 化（M0監査P3）
- app/assets/balance は canonical のコピー（CIで同期チェック中）。将来はビルド時同期に

### M1 監査ゲート（2026-08-26）→ NO-GO → 対応

Opus 4.8 並列3体で M1 を監査（実測裏取り）。**総合 NO-GO**（アーキ=条件付きGO、UX=NO-GO、リリース=NO-GO）。指摘に3バッチで対応:

**対応(1/3) 予約制・correctness（commit 2dab1b0）**
- engine.tick を TickResult 返却型に（発明ボーナス正確値・週次売上/販売数・昇格）
- Discover コマンド追加（材料費なしでレシピ付与＝魂の記憶#5＋デバッグ用、engine経由で決定論維持）
- 予約制(§2.1)実装: 発注/生産は reserve のみ、時間はメイン画面の速度バー＋「次の週へ」で進める
- 発明ボーナス表示を正確値に・多重発明キュー化・先週の売上/昇格をメイン常設・ボトルネックを ActionChip 化（タップで直行§12.3）・デバッグ全発見を Discover 経由に

**対応(2/3) オンボーディング（commit b5537c5）**
- OnboardingFlow（前世カットイン→女神転生→目標）＋GameRoot（イントロ→誘導開発→フリープレイ）＋DevelopScreen(tutorial:true)でプリン素材事前選択＝first_invention保証。tutorialActiveProvider（永続化・2周目省略はM3のsave連携時）

**対応(3/3) AC-14/AC-17（本コミット）**
- **AC-14**: CIに `ac14-debug-excluded` ジョブ追加。release ビルドの App バイナリを strings で走査し DebugMenu/debugGrant/debugStep が不在であることを hard gate（監査が手動でやった検証を自動化）
- **AC-17**: アートバイブル（`docs/art-bible.md`：32色パレット・解像度・光源・アウトライン・パーツ合成）＋`assets/palette.json`（固定32色）＋`tool/asset_pipeline`（quantize：固定パレット減色＋近傍補間サイズ正規化／audit：パレット逸脱・サイズ検査）＋CI `asset-audit` ジョブ。**この環境ではAI画像生成不可のため、パレットのみで手続き生成したサンプル3点（coin/herb/vial）でパイプライン→監査→CIをend-to-end実証**。実AIアセットの量産テスト（1種族＋アイコン20点/game-visual-qa）は画像生成可能なセッションに限定繰り越し（要件§21.2の基盤＝本書＋パレット＋パイプラインはM1で確定）
- **ADR-0001**（`docs/adr/`）: balance_hash↔セーブ互換の密結合（M0監査P3）。MVPは不一致＝破棄、リリース後は追記のみ原則、v1.0でbalanceマイグレーション表

M1残（画像生成環境が必要／M3以降）: 実AIアセット量産テスト、tutorial永続化＋2周目省略、Build in Public。

## M2 実装（2026-08-26、計画→監査→是正→実装）

計画は `docs/m2-plan.md`、監査と是正は `docs/m2-plan-audit.md`。是正済み順序で実装:

- **#1 需要プール公平配分**（commit f812464）: id順ドレイン→water-fill（engine.dart）。監査D-2修正。
- **#2 報酬間隔計測＋ゲート**（commit 501cf2f）: stats.dart（percentile/IntervalStats）＋runner報酬tick収集（core無改変）＋gate.dart（hard=AC-04/07、soft=AC-05/08/10）＋`--gate`＋CI balance-gate。
- **#3 コンテンツ拡張**: 素材8→20（id8-19）、レシピ11→43（id11-42追記、ADR-0001準拠で既存不変）。band1=37（AC-04余裕）/band2=4/band3=2、発明8種(18.6%)。全43comboユニーク（loaderが検証、新hash 1861475d）。実測: 発見37種でAC-04 PASS、破産0%、決定論維持。develop画面の開発ボタンを下部固定（20素材でスクロール落ちしないUX改善）。app15テスト通過。
  - AC-05は p90 879→110 に改善（events #4 で更に無報酬ギャップを埋める）、AC-08御用達0%は #5 economy校正待ち。
- **#4 イベントシステム**（監査Aの5設計判断を反映）: events.dart（型＋堅牢パーサ）／events.json 30本（王国4[内royal forced]・災害5・好機5・キャラ6・勇者3・転生者3・周回専用4、2択以上23本=76%）。engine統合＝tick末尾に固定2ドロー（events空ならスキップ＝headlessハッシュ不変, A-D1/A-D2）・forced royal(fame≥3000, RNG非消費, rank-up前評価 A-D4)・weighted二分探索(候補数非依存 A-D3)・shuffle-bag（全消化で再開）・**pity timer**（58tick無イベントで確定発火＝AC-05のmaxGap保証）。ChooseEventコマンド＋効果適用（funds/fame/grant_recipe/material/product/royal_flag、clampCap経由）。御用達ゲートにroyalCleared AND（events有効時のみ）。state に event フィールド追加（全て条件付きtoJson＝events空で従来ハッシュ完全維持）。app: 自動ポーズ＋EventDialog。
  - **バランス調整**: event_fire_permille=15・event_pity_ticks=58。bot はイベントで survival-best 選択（royalは受諾＝資金+）。costly災害に min_fame ゲート。
  - **AC-05が PASS に**（p50=19/p90=58/maxGap=58 ≤ 26/60/120）＝events+pity で報酬間隔問題を解決。AC-04/07も PASS で **GATE OK**。AC-08/10 は soft のまま（#5/M3）。
  - テスト: EV-01〜12（決定論・RNGドロー不変・hash条件付き・royal確定発火・御用達ゲート・効果適用・events-less回帰・堅牢化）＋events-loaded決定論＋app event flow＋event golden。core58+headless21+app17=96通過。

### 旧・M1計画メモ

アートバイブル確定＋AI生成→量子化パイプライン→顔グラ1種族＋アイコン20点の量産テスト（/game-visual-qa合格がゲート）／Build in Public開始。
