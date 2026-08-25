---
name: expert-panel
description: 対象ドキュメント（要件定義/GDD/計画書）に対して6分野の専門家レビューを並列実行し、指摘を統合して文書に反映するオーケストレーションスキル。「プロの目で総点検して」「専門家レビューして」というときに使う。引数で対象ファイルを指定（省略時 docs/requirements.md）。
user-invocable: true
---

# Expert Panel（専門家パネル総点検）

対象文書に対し、以下の6レンズの専門家エージェントを**並列で**起動する。各エージェントには (a) 担当レンズのスキルファイルを読んで方法論として適用すること、(b) 一般論禁止・対象文書の実数値で指摘すること、(c) 優先度順の構造化出力、を指示する。

| # | レンズ | 適用するスキル |
|---|---|---|
| 1 | ゲームデザイン核心（コンセプト・ループ・GDD品質） | .claude/skills/game-review, plan-design-review |
| 2 | 経済・数値設計（カーブ・報酬間隔・メタ進行） | .claude/skills/sim-economy-review, balance-review |
| 3 | UX・オンボーディング・リテンション | .claude/skills/game-ux-review, player-experience |
| 4 | マネタイズ・審査・ASO・法令 | .claude/skills/jp-ios-monetization-review, launch-checklist |
| 5 | 技術アーキテクチャ・実装リスク | .claude/skills/game-eng-review, architecture-decision |
| 6 | スコープ・工数・完成可能性 | .claude/skills/solo-dev-reality-check, scope-check, estimate |

注: gstack系スキル（game-review等）の bash プリアンブル（セッション記録等）は実行不要。レビュー基準・チェックリスト部分のみを方法論として使う。

## 統合フェーズ（パネル結果が揃ったら）

1. 全指摘を集約し、重複を統合。**採用／不採用を1件ずつ判断**し、不採用には理由を付す
2. 採用指摘を対象文書に直接反映（版数を上げ、冒頭に変更点サマリーを追記）
3. `docs/expert-review-log.md` に「指摘→採否→反映箇所」の監査ログを残す
4. 反映後、指摘同士の矛盾（例: UXは追加を、スコープは削減を要求）は**完成可能性を優先**して裁定する

## 出力

ユーザーへの最終報告は: 採用した重要変更トップ5 / 不採用にした主要指摘と理由 / 文書の残リスク。
