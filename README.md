# 異世界カンパニー

過労死したコンビニSVが異世界に転生し、行商人から大商会主へ成り上がる周回型経営シミュレーション。iOS（Flutter）個人開発。

> 「前世の知識で、異世界の経済を塗り替えろ。」

## ドキュメント

- [要件定義書 v1.0【完全版】](docs/requirements.md) — 実装基準書。全初期値・受け入れ条件AC-01〜17・ADR一覧まで確定
- [専門家パネル監査ログ](docs/expert-review-log.md) — 6分野レビューの採否記録
- [開発ログ](docs/dev-log.md) — マイルストーンごとの実装・検証記録

## 開発状況（週20h実働・外注ゼロ内製・リリース目標 2027年4月下旬）

- [x] 要件定義 v1.0 完全版（2026-08-25。専門家パネル32件反映＋全初期値確定）
- [x] **M0: 技術基盤**（2026-08-25 実装・検証完了）決定論コア／PCG32／ティックエンジン／balance JSON／セーブ／ヘッドレスランナー／CI。AC-01/02/03 通過（破産0/1000・リプレイ一致・0.3µs/tick）
- [ ] M1: 第1層ループ vertical slice（〜2026-11-08）Flutter app・プリン発明演出・アートバイブル＋AI内製量産テスト・Build in Public開始

## ビルド・実行

```bash
dart pub get --directory=packages/core
dart pub get --directory=packages/headless
bash tool/check_forbidden.sh                 # §2.2 禁止則チェック
cd packages/core && dart test                # コアのユニットテスト
cd packages/headless && dart test            # 決定論・save/load テスト
dart run bin/run.dart --balance ../../assets/balance --lives 1000 --seed 1 --verify-replay
dart run bin/trace.dart 1                     # 単一人生の週次トレース
```
- [ ] M2: 人生ループ 1周60分（〜2027-01-10）
- [ ] M3: 転生ループ＋IAP（〜2027-02-21）T-12プロモ開始
- [ ] M4: チュートリアル＋TestFlight（〜2027-04-04）→ 審査 → リリース
