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

### 次（M1・W4〜, 目標2026-11-08）

Flutter appパッケージ／第1層vertical slice（発注→開発→生産→販売→再投資）／プリン発明演出／主要4画面／アートバイブル確定＋AI生成→量子化パイプライン→顔グラ1種族＋アイコン20点の量産テスト（/game-visual-qa合格がゲート）／デバッグメニュー（ビルドフレーバー分離でAC-14）／Build in Public開始。
