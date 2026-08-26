# M4 実装後監査 結果と是正

**日付**: 2026-08-27 / **方式**: Opus並列2体で実装コード（M4-A/B/D）を敵対的監査、実走・実計算で裏取り

## 判定サマリー

- **M4-A（残コンテンツ recipes 43→75, events 30→60）＝GO**: 全hardゲートが seed×lives 15構成で安定PASS（AC-04 discovery 51／AC-05 15/58/58／AC-07 steady破産0%・attack≤5%／AC-08 御用達100%／AC-09 worst 68-115%）。重複comboゼロ（method文字列照合）・id連番・ADR-0001（id0-42不変）・全75レシピ正粗利・events全ref範囲内・決定論bit一致・cycle10本がlife2+のみ発火。**重大度Highゼロ**。
- **M4-B（アンロック効果）／M4-D（審査準備）＝条件付きGO**: 実装堅牢（grant_recipes=band1定番のみ・発明除外・byte一致／speed3ゲート正しい／分析seam NoopデフォルトPII無し／課金法令表示・復元2箇所・kReleaseMode安全）。**景表法の要是正1件**＋軽微2件。

## 是正（本監査で修正済み）

| ID | 指摘（重大度） | 是正 |
|---|---|---|
| **P1** | **ペイウォール「+N項目解放」が非機能ノードを含み優良誤認（景表法・中）**。full 12個中 実機能は4個（残8個は今後有効化で購入不可）なのに「+12解放」と約3倍誇張 | `UnlockSummary.compute` を **functional かつ full の未所有数のみ**カウントに是正（=4）。paywall/soul_memory の表示が自動追従。`entitlements_test` を functional基準に更新（<全full を保証）。ADR-0003に明記 |
| **A-Low1** | **band2/3レシピを付与するイベント5本が min_life:1**＝life1で band>allowedBandMax の無音棄却で「空振り報酬」（軽微・correctness安全） | ev30/34/40/44/49（行商人/流浪職人/老舗/前世記憶/天才発明家）に `min_life:2` 付与。life1に残る band>=2 grant ゼロを検査で確認 |
| **B-P2** | **`AnalyticsEvents.restore` 定義済みだが未発火**（checklistは「発火済み」＝過大申告・軽微） | `restorePurchases` 成功時に発火追加。analytics_test を unlock_bought/purchase_full/restore もアサートに拡張 |
| **B-P3** | **ADR-0003/paywall免責が speed3実装で陳腐化**（倍速×3を「未実装」列挙）（軽微・不整合） | ADR-0003 の未実装列挙から倍速×3を除去＋実装済み明記。paywall免責の例示を「流行予測」等に差替 |
| **A-Low2** | EV-13テストが新cycle(54-59)を非網羅（回帰ガード穴・軽微） | `hasCycle` を `events[id].minLife >= 2` に一般化 |
| Info | §10.1粗利レンジ逸脱 band1 6本（11-13G、例示max10G超）＝§10.1は起点で hard cap でない。修正不要・記録のみ | — |

## 是正後の検証

`check_forbidden`両ガード／core 88・headless 21・app 40 テスト緑／`flutter analyze` clean／`--gate --with-events`：全hard PASS（AC-04/05/07/08）＋AC-09 soft PASS＋AC-10 soft FAIL（既知・v0.9）＝GATE OK／events込み `--verify-replay` 4bot bit一致。

## M4残・繰越（honest開示）

- **v0.9送り（ユーザー決定）**: 新システム（流行/劣化/種族/離職/オフライン/自動化 #15/#16）＝完全版の残feature-gatedノード。実装時に `functionalModTypes` へ追加すれば paywall解放数・購入可が自動追従。AC-10再校正も流行システム実装とセット。
- **ユーザー依存（M4最終、`docs/review-checklist.md`）**: RevenueCat実キー・課金プロダクト(¥1,200非消耗)登録・EULA/プライバシー/特商法の実URL・分析SDKキー＋PrivacyManifest・レーティング・実AIアセット・TestFlight署名・審査提出。
- **M4定義の残**: チュートリアル拡充（M1オンボーディング＋C-6永続化済み、網羅性は実機テストで確認）・アセット統合（パイプライン実装済み、実生成は別環境）・AC-06実機1周実測。
