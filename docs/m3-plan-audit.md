# M3 計画監査 結果（v1計画への敵対的レビュー）

**日付**: 2026-08-26 / **方式**: Opus並列3体で v1計画（`docs/m3-plan.md`のv1）を敵対的監査。P1は実計算・実走で裏取り。
**総合判定**: 3体とも **条件付きGO**（実装前に潰すべきCritical/High多数）→ **v2計画で是正済み**＋**ユーザー決定でP1方針確定**。

## P1（経済）— 中核前提が反証された（最重要）

**判定**: 条件付きGO。実装作法は健全だが「設備Lv×品質★の複利で§10.2 near-geometricに乗る」は**実データ・実計算で否定**。

- **閉形式証明**: fame帰還ループ `fame_{t+1}=fame_t·ρ+定数`、`ρ=1+demandPerFame·price/(100·famePerSalesG)` は**定数**。§10.2要求ρは**漸減**（100→2000:1.0075 / →40000:1.0050 / →800000:1.0038 / →15M:1.0037）。定数ρは漸減ρに構造的一致不能（序盤に合わせると終盤行き過ぎ、逆も同様）。
- **設備Lv・品質★はρに効かない**：有限上限の一度きり係数ジャンプ。上限到達後は必ず線形化（試算で2200w→2600w funds減少＝固定費+税がプラトーを削る）。
- **グリッドサーチ 19,440構成で ±50%内=0件**。∞容量・∞品質・0コストの上界（ρ=1.003）でも `400w:5559% / 2600w:772%`＝乗らない。
- **R2実証**: fame_per_sales_g 20→3500 単独で AC-10 が **+609%→-8%に反転**（攻めが放置に負ける）。M2 artisan事故と同型の多目的脆弱性。
- **C-2実証**: band-1発明（プリン/石鹸 margin=7）は非発明品（margin13/12…）に劣後→margin降順選択では発明品が永久に非選択。

**監査推奨**: **§10.2改訂を主、設備Lv/品質★は終盤頭打ち是正＋発明品価値付けの従**。→ **ユーザー決定①で採用**。

**その他指摘（v2で反映）**: 新state fieldはfromJson `?? default`必須（v1 state破壊防止）／AC-08 hard化は実測PASS後限定／発明品選択関数をmargin単独から変える具体仕様をADRに。

## P2（メタ/セーブ）— Critical構造欠陥

**判定**: 条件付きGO。層設計（fromMeta境界・MetaReader・条件付きhash/toJson）は健全。ブロッカー2件。

- **Critical-1**: 現行`saveMigrations`は`state`サブツリーのみ変換。meta は doc トップレベルなので `saveMigrations[1]` が注入不能。**機構をdoc全体変換へ再設計**要。encodeSave/decodeSaveのシグネチャ・戻り型変更。既存save_test（`expect(saveMigrations, isEmpty)`含む）はv2で落ちる＝更新対象。
- **Critical-2**: 新state field（equip/quality）を`m['x'] as int`必須読みすると v1 state で TypeError。**toJson条件付き出力＋fromJson `?? default`を対で必須**。
- **R3決着**: balance_hash mismatch がマイグレーションを影に隠す。**リリース前ゆえ救う実v1セーブは存在しない**→選択肢A「マイグレーションは機構検証に格下げ、economy hashでv1正当破棄、AC-15は合成テストで機構健全性のみ検証」を明記。
- **High-1**: 無限ノード（§8.4 #21/#22の1.6^n）は購入回数カウンタ必要（Setでは不能）。fromMetaの乗算は回数ぶんループ・id昇順・§10.5 clamp。
- **High-3/R6**: 加算×乗算交錯のgolden testで適用順固定。check_forbidden.shに meta.dart追加＋headless fromMeta参照をfail。
- **Medium-1**: **項目数24 vs 要件22、#16自動発注を無料→有料に勝手移動**。§8.4確定表をsingle source of truthに転記せよ。
- **R4是正**: P2は state.dart を **fromMeta factory のみ**触る（toJson/fromJsonはP1）→衝突面ゼロ。

## P3（ペイウォール/統合）— Critical 3件

**判定**: 条件付きGO。インターフェース分離・AC-16動的算出は妥当。

- **Critical-1**: **tier境界が§8.4と正面矛盾**。要件は #16=無料 / #15=完全版 / #3のみ「自動」（クリア付与・非課金）。v1は「自動化=有料」と誤読し**無料の#16を課金背後に封印**（§14.1信頼設計違反）。tier enumを§8.4語彙に正確化、Entitlementsゲートは`full`のみ。
- **Critical-2**: **app永続化基盤が存在しない**（path_provider無・セーブ呼び出し無・soulPoints再起動消滅）。v1「app層atomic write既存」は誤り。→ **P0として明示計上**。
- **Critical-3**: **復元購入導線欠落**（App Store 3.1.1／§14.4はショップ＋設定2箇所常設）。ショップ画面(#18)未計上。→ 追加。
- **High-2**: entitlementsは**balance_hash非依存の別ファイル**に（meta相乗りだとeconomy改訂で課金実績が消える＝返金/審査リスク）。
- **High-1**: stub IAP は `kReleaseMode`分岐（release=準備中＋ボタン無効化、debug=即成功）。M3 release buildは審査に出さない（ADR明記）。
- **High-3/4**: C-4(AC-06)は意図的先送りだが**明記要**。C-3(AC-10再校正)の"据え置き可"は撤回し再測定必須化。
- **健全性の確認**: canonicalJsonはキーソート済み（R4(b)非問題）。sealed switchはコンパイラ網羅（R4(a)はgitマージのみ）。Grantが外部流入の正規経路。MetaReaderは疎結合可。
- **スコープ**: P0+P1+P2+P3は週20hに過大→M3a/b/c分割推奨。→ **ユーザー決定②で一括を選択**（v2でR7として据え置き負債を明示追跡）。

## ユーザー決定（2026-08-26）
1. **§10.2を改訂**（economyオーバーホールで乗せない）。→ P1方針転換、ADR-0002に不到達証明。
2. **一括M3のまま**（分割しない）。→ R7で据え置き負債を明示追跡、内部チェックポイントで各ゲート緑化。

→ 全Critical/High を v2計画（`docs/m3-plan.md`）に反映済み。次工程＝**実装**（P0→P1→P2→P3）。
