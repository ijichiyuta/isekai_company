# App Store 審査チェックリスト（要件 §23.3 / §14 / §16）

M4-D スキャフォールド。**状態凡例**: ✅実装済 / 🟡枠のみ(M4で実配線・ユーザー依存) / 🔵v0.9 / 🔴ユーザー作業。

## §23.3 チェック項目

| # | 項目 | 状態 | 根拠 / 残作業 |
|---|---|---|---|
| 1 | **IAP復元**（App Store 3.1.1） | ✅ | ショップ(魂の記憶)＋設定の2箇所常設（`soul_memory_screen`/`settings_screen`）。`GameController.restorePurchases`。テスト有 |
| 2 | **購入前明示**（価格・非消耗・追加課金なし） | ✅ | `paywall.dart` 法令セクション：`¥1,200 買い切り（非消耗）…`（`fullVersionPriceLabel`） |
| 3 | **EULA・プライバシーポリシー・特商法リンク** | 🟡 | paywall にリンク枠有。URLは `entitlements.dart` の `eulaUrl/privacyUrl/tokushohoUrl`（プレースホルダ、要実URL＝🔴）＋タップで実ページを開く配線（M4） |
| 4 | **デバッグ除外CI**（Guideline 2.3.1） | ✅ | `.github/workflows/ci.yml` の `ac14-debug-excluded`（DebugMenu/debugGrant/debugStep 不在検証）。IAP stub は kReleaseMode 定数畳み込み（ADR-0003） |
| 5 | **導線=解放数の実装一致 自動テスト** | ✅ | `UnlockSummary.compute`（balance由来・AC-16）＋ `entitlements_test`（合成balanceで追従を検証、ハードコード無し） |
| 6 | **プライバシーマニフェスト / ATT / SKAdNetwork** | 🔴 | 分析SDK配線時（`analyticsProvider` を実クライアントに差替）に PrivacyInfo.xcprivacy 追加。現状 `NoopAnalytics`（PIIなし・ネットワークなし） |
| 7 | **レーティング**（年齢別） | 🔴 | App Store Connect で設定（暴力/課金要素申告）。本作は買い切りのみ・ギャンブル要素なし |
| 8 | **特商法URL** | 🔴 | ホスティング＋App Store Connect メタデータに記載（#3と同URL群） |
| 9 | **アカウント削除**（Guideline 5.1.1(v)） | 🔵 | クラウドセーブ導入(v0.9)と同時。MVPはローカルセーブのみ＝サーバー個人データ無し |

## 課金テスト手順書（要件 §22.5 / §23.3：手動手順）

M4 の RevenueCat 配線後、TestFlight/Sandbox で実施：
1. **購入**: 未購入→paywall→完全版購入→full解禁（tree の🔒が購入可に）。
2. **復元**: 別端末/再インストール→ショップ or 設定「購入を復元」→full復元。
3. **Ask to Buy**（ファミリー共有）: 承認待ち→承認後に反映。
4. **返金剥奪**: 返金後に full 権限が失効（RevenueCat webhook）。
5. **機内モード**: オフラインで完全版が RevenueCat キャッシュで動作（要件§22.1）。
6. **価格表示**: ストアローカライズ価格が paywall に出る（`fullVersionPriceLabel` を実価格に差替）。

## RevenueCat 統合構造（M4 実配線、シーム済み）

課金は `IapClient` シーム（`app/lib/game/iap_stub.dart`）で抽象化済み。M4 では：
1. `purchases_flutter` を pubspec に追加、`Purchases.configure(apiKey)`（🔴 実キー）。
2. `RevenueCatIapClient implements IapClient` を新規：
   - `available` → オファリング取得可否。
   - `purchaseFull()` → `Purchases.purchaseStoreProduct`／`purchasePackage`。
   - `restore()` → `Purchases.restorePurchases`。
   - エンタイトルメント判定は `customerInfo.entitlements.active['full']`。
3. `iapClientProvider` を `RevenueCatIapClient` に差替（1行）。`GameController`/UI は無改修（シームのため）。
4. `Entitlements`（別ファイル永続）は RevenueCat が権威になったら「機内モード用キャッシュ」に降格（要件§22.1）。
5. **M3/現状の release は審査提出しない**（stub・価格未定・SDK未配線、ADR-0003）。提出は M4 完了後。

## 分析（要件 §24 M4「分析」/ §26 成功指標）

`AnalyticsClient` シーム済み（`app/lib/game/analytics.dart`）。ファネルイベント発火済み：`tutorial_done` / `life_end`(score,rank,reason) / `rebirth`(life) / `unlock_bought` / `purchase_full` / `restore`。M4 で `analyticsProvider` を実SDK（Firebase/Amplitude 等・🔴キー）に差替＋PrivacyManifest。**2周目突入率・課金率**（§26）を計測。

## ユーザー作業サマリー（🔴）
RevenueCat アカウント/APIキー・App Store Connect 課金プロダクト(¥1,200 非消耗)登録・EULA/プライバシー/特商法の実文面とホスティングURL・分析SDKキー・レーティング申告・実AIアセット生成・TestFlight署名アップロード・審査提出。
