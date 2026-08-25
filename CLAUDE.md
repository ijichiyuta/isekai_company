# 異世界カンパニー

周回型（転生）経営シミュレーション。iOS/Flutter、個人開発。要件定義: `docs/requirements.md`（正）。設計判断はこの文書と整合させること。

## インストール済みスキル（.claude/skills/）

**企画・設計**: /game-ideation /game-direction /game-review /plan-design-review /pitch-review /game-import /spark-lens /map-systems /consistency-check /architecture-decision
**数値・体験**: /sim-economy-review（周回シム経済・本作特化） /balance-review /player-experience /game-ux-review /feel-pass /playtest
**計画・スコープ**: /solo-dev-reality-check（完成可能性監査） /scope-check /estimate /prototype-slice-plan /vertical-slice /create-epics /create-stories /sprint-plan /milestone-review
**実装・品質**: /game-eng-review /gameplay-implementation-review /implementation-handoff /game-qa /qa-plan /game-debug /build-playability-review /triage /careful /guard /unfreeze
**アセット**: /art-bible /asset-spec /asset-audit /asset-review /game-visual-qa
**リリース・運用**: /jp-ios-monetization-review（日本iOS課金・審査・本作特化） /launch-checklist /release-checklist /game-ship /localize /game-retro /game-docs /game-codex
**総点検**: /expert-panel — 6分野の専門家並列レビュー→文書へ反映
**メタ**: /skill-creator /doc-coauthoring /frontend-design

gstack系スキルの bash プリアンブルは補助機能（ローカル記録）であり、失敗しても無視してよい。

## 作法

- バランス数値はコードに書かず `assets/balance/*.json`（要件 §8.2）
- ゲームロジックは pure Dart の core パッケージ。Flutter import 禁止（要件 §2.2）
- 大きな決定・工程完了時はメモリ更新（ユーザー指示）
