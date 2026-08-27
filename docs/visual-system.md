# ビジュアルシステム（実装リファレンス）

**版数**: v1.0（実装追従）
**目的**: 本作の**実際に動いているUIビジュアル**の技術リファレンス。`docs/art-bible.md` が
「AI量産アセット＋量子化パイプライン」という**設計意図**を定めるのに対し、本書は**現行ランタイムUIが
どう描画されているか**を記録する。

> **現状の正**: 実行時UIのビジュアルは **100% コード自作（画像アセット0）**。この環境に実画像生成が
> 無いため、アートバイブルが想定する 32×32 実アセットの量産は未実施であり、UIはすべて `PixelCanvas`
> による手続き描画で構成されている（要件§2.2「ゲームロジックは pure Dart」の姿勢を、描画にも適用）。
> アートバイブルのパレット方針・トーン哲学は本システムの `kArtPal` に受け継がれている。

---

## 1. アーキテクチャ（3層）

すべて `app/lib/ui/pixel/` にある。Flutter依存は描画層（`pixel_art.dart`）のみ。

| 層 | ファイル | 役割 | Flutter依存 |
|---|---|---|---|
| データ | `pixel_art.dart` `PixelSprite` | パレットキー文字の行 `List<String>` ＋ `Map<String,Color>` パレット | `dart:ui`(Color)のみ |
| 描画 | `pixel_art.dart` `PixelView` / `PixelTitle` | スプライトを整数倍・最近傍・AA無しで CustomPaint 描画するウィジェット | あり |
| 生成 | `pixel_canvas.dart` `PixelCanvas` | 手続き的にドットを打つ描画エンジン。最後に `toSprite()` で `PixelSprite` 化 | `dart:ui`(Color)のみ |
| 素材 | `sprites.dart` | `PixelCanvas` で各スプライトを組み立てる工房＋公開カタログ＋`kArtPal` | あり(art) |

**データフロー**: `_buildXxx()`（sprites.dart）が `PixelCanvas` に描く → `toSprite(kArtPal)` →
`final PixelSprite xxx` として公開 → 画面が `PixelView(art.xxx, height: N)` で表示。

## 2. PixelCanvas API

`PixelCanvas(width, height)` は全セル透明（`.`）で始まる。キーは1文字（パレット参照）、`.`/半角空白＝透明。
座標系は左上原点、光源は**左上**固定。

- `set(x,y,c)` / `at(x,y)` — 1ピクセル書き込み／読み出し（範囲外は無視・`.`を返す）
- `rect(x,y,w,h,c)` `hline(x,y,w,c)` `vline(x,y,h,c)` `border(x,y,w,h,c)` — 矩形・線・枠
- `rampV(x,y,w,h,tones)` `rampH(...)` — トーン配列で階調塗り（縦／横）
- `dither(x,y,w,h,c1,c2)` — 市松ディザ（2色の中間調）
- `disc(cx,cy,r,c)` `discShaded(cx,cy,r,tones)` `ellipse(cx,cy,rx,ry,c)` — 円・陰影付き円・楕円
- `line(x0,y0,x1,y1,c)` — Bresenham直線
- `starFill(cx,cy,rO,rI,points,tones)` — 多角星（even-odd判定）
- `outline(c)` — 不透明シルエットを8近傍で縁取り（透明セルのみ）
- `selout(outlineKey,litKey)` — selective outlining。上/左（受光側）の輪郭を明色に置換
- `shadow(cx,cy,rx,ry,c)` — 楕円の接地影（透明セルのみを塗る）
- `fillBehind(x,y,w,h,c)` — 背景の塗り足し
- `toSprite(palette)` — 現在のキャンバスを `PixelSprite` に確定

これらの基本動作は `app/test/pixel_canvas_test.dart`（11本）が担保している。

## 3. パレット `kArtPal`（v3・色相シフト）

プロのドット絵と平坦なクリップアートを分ける核心が**色相シフトしたトーンランプ**：ランプが明るくなる
ほど色相を暖色（黄寄り）へ回し彩度を落とす／影は寒色へ回し彩度を残す（Slynyrd / Derek Yu）。輪郭は
純黒でなく**暗いプラム**（`K`）、受光辺は `@`（selout）で持ち上げる。

キー割り当て（暗→明）:

| 用途 | キー | 用途 | キー |
|---|---|---|---|
| 輪郭 / 受光輪郭 | `K` `@` | 肌 | `y z A B` |
| 木材 | `a b c d e` | 髪 | `C D E` |
| 壁(漆喰) | `f g h i` | 青布 | `F G H` |
| 緑(屋根/看板) | `j k l m` | 白布(エプロン) | `I J L` |
| ガラス | `n o p q` | 赤(日除け/チュニック) | `M N O` |
| 空(窓の外) | `r s t` | 灰/金属 | `P Q R S` |
| 金 | `u v w x` | 葉 | `T U V` |
| アクセント | `Z`(頬紅) `#`(白) `-`(影) `~`(淡影) | | |

`kPal`（旧・カイロ系の素朴パレット）は互換のため残置。新規スプライトは `kArtPal` を使う。

## 4. 適用しているプロ技法

- **色相シフトのトーンランプ**（§3）— 単一色を明暗するだけの平坦さを避ける
- **selective outlining** — 一律黒縁を廃し、受光辺は明色・陰辺は暗色プラム
- **外周アンチエイリアス禁止** — `PixelView` は最近傍・整数倍のみ。背景（`background.dart`）だけは
  非ドットのグラデ／放射光でコントラストを作る
- **チビ体型のキャラ規則** — `_person()` は 54×74（約4頭身）、なで肩、顔を縁取る髪、FE風の最小1px顔、
  頬紅アクセント（`Z`）。関連: メモリ `isekai-company-visual-direction`

## 5. スプライトカタログ（公開名・`sprites.dart`）

- **施設**: `shopHd`（=`shop`）
- **人物**: `heroHd`(=`hero`) / `villagerHd`(=`customer`) / `ladyHd` / `elderHd` / `adventurerHd` / `goddess`
  — いずれも `_person(...)` の装い違い
- **UIアイコン(24×24)**: `coin` `star` `gear` `beaker` `factoryIcon` `storefront` `cart` `flame` `sparkle`
- **小物**: `crate` `window` `plant` `barrel`
- **カテゴリ**: `catFood` `catTool` `catCloth` `catMed` `catLux` ＋ 汎用 `sack`
  - `categoryIcon(String)` が balance の `category` を対応アイコンへ写像（未知は `sack`）。
    整合性は `app/test/category_icon_test.dart` がガード。
  - 日本語表示名は `app/lib/game/format.dart` の `categoryJa(String)`。

> `factory` は `package:meta` の `@factory` と衝突するため `factoryIcon` に改名済み（未prefix import対策）。

## 6. 新しいスプライトを足す手順

1. `sprites.dart` に `_iXxx()`（または `_buildXxx()`）を追加：`PixelCanvas` に描き `toSprite(kArtPal)` を返す
2. `final PixelSprite xxx = _iXxx();` を公開カタログに追加
3. 画面から `PixelView(art.xxx, height: N)` で使用。情報を持つアイコンには `semanticLabel` を付ける（a11y）
4. `app/test/pixel_sprites_test.dart` の検証マップ（幅・パレット不変条件）とコンタクトシート／プレビュー
   ゴールデンを更新（`flutter test --update-goldens`。macOS専用・Hiragino）
5. `flutter analyze` ＋ 全テスト緑を確認

## 7. テスト資産

- `app/test/pixel_canvas_test.dart` — 描画プリミティブの単体テスト（回帰を即検出）
- `app/test/pixel_sprites_test.dart` — スプライト検証＋コンタクトシート／各種プレビューのゴールデン
- `app/test/screens_golden_test.dart` — 13シーンの画面ゴールデン
- `app/test/category_icon_test.dart` — balance→カテゴリアイコン整合性

## 8. 関連ドキュメント

- `docs/art-bible.md` — 設計意図（AI量産アセット／パレット哲学／解像度規定）。本書はその実装追従版
- `docs/requirements.md` — §2.2 pure Dart、§7/§21.2 アセット要件、AC-17
- `.claude/skills/pixel-art/SKILL.md` — 一般的なドット絵手法の方法論（色相シフト・selout・解像度）
- メモリ `isekai-company-visual-direction` — 方向性の確定事項（カイロ系→JRPGチップ、絵文字全廃）
