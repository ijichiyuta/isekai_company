# M3 実装後監査 結果と是正

**日付**: 2026-08-26 / **方式**: Opus並列3体で実装コード（P0-P3）を敵対的監査、実走・実計算で裏取り

## 判定サマリー

- **P0/P2（永続化・魂の記憶メタ）＝GO**: 挙動バグゼロ。計画監査の全Critical/High（v2マイグレーション機構・fromMeta決定論・byte一致・無限ノード・破損フォールバック）が実装で潰れていることを実走確認（敵対的エッジ73件＋replay 200ライフ）。
- **P1（経済）＝条件付きGO**: 経済エンジン・ゲート校正は健全、AC-08 hard化は**500ライフ実測100%到達（worst到達tick 2344＝536余裕）で脆くない**、C-2発明比率≈75%。要是正2件（下記H-1/H-2）。
- **P3（ペイウォール）＝条件付きGO**: 課金境界は堅牢（§8.4 tier一致・バイパス不能・復元2箇所・AC-16真動的・別ファイル永続・release無料解放なし）。要是正3件（下記H-3/M-1/M-2）。

## 是正（本監査で修正済み）

| ID | 指摘（重大度） | 是正 |
|---|---|---|
| **H-1** | **設備Lv・品質★を人間が購入するUIがappに無い**（bot専用）→改訂§10.2はシミュ上のみ成立、実プレイはM2の8M頭打ちのまま（High） | production_screen に `_UpgradePanel` 追加（設備強化・品質向上を予約、幾何コスト表示）。game_controller に equipmentLevel/qualityStar/weeklyCapacity/cost getter。生産能力表示を設備込みに是正。controllerテスト追加 |
| **H-2** | §10.5 overflow：販売収益の累積が clampCap 未適用（validator-legal値でwrap）＋engine誤コメント（実balanceは安全だが不変条件が破れる、M2由来）（Medium） | 水fill両ループの `weeklyRevenue` 累積を `clampCap(...)` 化。誤コメントを実際の保証に訂正。実balanceでは clampCap が恒等＝hash不変（6e3a73c）を実測 |
| **H-3** | **tracked-only mod によるペイウォール価値空洞化**＝完全版有料ノードの過半が購入しても効果未配線、なのにpaywall文言が便益を謳う（景表法・優良誤認リスク）（High） | 経済系mod（production_bonus/sales_bonus/order_discount）を実配線（state 3フィールド＋engine capacity×/pool×/order cost×＋fromMeta）。`functionalModTypes` 追加＝未実装modは `tryPurchaseUnlock` が拒否＋ツリーUIに「今後有効化」表示。paywall文言を実装済み便益に限定＋「今後有効化」明示。core/appテスト追加 |
| **M-1** | 「stub即成功がreleaseに混入しない」CI検証欠落＋iap_stubコメントが実在しないゲートに言及（Medium・実害低） | iap_stubコメントを kReleaseMode 定数畳み込みの正確な記述に訂正。StubIapClient契約テスト追加。ADR-0003起票 |
| **M-2** | 「M3 release非提出」ADR未作成（計画で必須化）（Medium） | **ADR-0003**「M3リリースは審査提出しない」起票（stub IAP・価格未定・RevenueCat未配線・未実装ノードの購入不可＋文言限定＝景表法回避） |
| Low | ドキュメントdrift（ADR-0002 fame_g 460→**640**／AC-09「±2%」→10ライフ±40%/300+収束の実態／発明share「32%」→**75%**）、meta.dart 無限ノードid（#21/#22→id22/23） | 全て訂正 |

## 是正後の検証

`check_forbidden`（core clean＋headless meta-less）／core 87・headless 21・app 37 テスト緑／`flutter analyze` clean／`--gate --with-events`：**AC-04/05/07/08 hard PASS・AC-09 soft PASS（worst 84%）・AC-10 soft FAIL（既知）**＝GATE OK／events込み `--verify-replay` 4bot bit一致・balance hash不変（6e3a73c＝経済multiplierはstateフィールドで default0＝決定論不変）。

## M3後への繰越（監査が指摘・honest開示）

| # | 項目 | 期限 |
|---|---|---|
| C-A | AC-10手動優位 +10..20% 再校正（#15/#16自動behavior実装＋放置bot統合が前提。現状tracked-only） | M4（機能実装時） |
| C-B | 完全版の未実装ノード（種族/自動化/倍速×3/流行/劣化/離職/オフライン/ヒント/開示）の効果実装＝`functionalModTypes`拡張 | M4 |
| C-C | 課金法令表示（価格/EULA/プライバシー/特商法/自動更新なし）＋RevenueCat配線＋復元e2e | M4（審査提出前） |
| C-D | AC-06 実機1周60分実測（経済改訂後の実測） | M3後半/M4冒頭 |
| C-E | §10.3「商会=設備Lv5」ランク条件の配線（設備Lvは実装済み） | 任意 |
| C-F | CIゲート lives=10→100+（AC-05等の統計強化。AC-08は10でも536tick余裕で安全） | 任意 |
