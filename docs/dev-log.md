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

### 次（M1・W4〜, 目標2026-11-08）

Flutter appパッケージ／第1層vertical slice（発注→開発→生産→販売→再投資）／プリン発明演出／主要4画面／アートバイブル確定＋AI生成→量子化パイプライン→顔グラ1種族＋アイコン20点の量産テスト（/game-visual-qa合格がゲート）／デバッグメニュー（ビルドフレーバー分離でAC-14）／Build in Public開始。
