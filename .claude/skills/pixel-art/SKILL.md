---
name: pixel-art
description: "Author high-fidelity, in-code pixel art for 異世界カンパニー (no image-gen tool needed). Procedural PixelCanvas + tonal ramps → professional-looking sprites. Use when creating/upgrading any sprite in app/lib/ui/pixel/."
user-invocable: true
allowed-tools: Read, Edit, Write, Bash
model: sonnet
---

# Pixel-art production (in code, no raster generator)

All game art is drawn **in Dart** via `app/lib/ui/pixel/` — no bundled images
(要件§8.2 内製). Two layers:

- `pixel_art.dart` — `PixelSprite` (rows of palette keys) + `PixelView` (crisp,
  integer-scaled renderer, no AA) + `PixelTitle`.
- `pixel_canvas.dart` — `PixelCanvas`, a mutable grid with drawing primitives
  (`rect/hline/vline/border/rampV/rampH/dither/disc/discShaded/ellipse/line/
  outline/shadow/fillBehind` → `toSprite(palette)`). **This is how detail is
  achieved**: compose with loops + gradients, don't hand-type grids.

## The rules that separate pro art from programmer art

1. **Resolution.** Icons ≥24²; characters ≥48×64; hero props/buildings ≥96 wide.
   Small grids (12²) look crude — go bigger and let `PixelView` scale down.
2. **HUE-SHIFTED ramps, not flat fills.** THE technique that separates living
   pixel art from clip art (Slynyrd/Derek Yu): every material gets **3–5 tones**
   in `kArtPal` where, as the ramp brightens, the **hue rotates ~15–20° toward
   warm/yellow and desaturates**; shadows rotate **cooler** (skin→rosy-red,
   blue→indigo, green→teal) and keep more saturation. A pure brightness-only ramp
   is the #1 beginner tell. Light source **top-left** (highlights top-left,
   shadow bottom-right). Shade with `rampV`/`discShaded`.
3. **Selective outline (selout).** Outline with a dark desaturated color (`'K'` =
   plum, NOT pure black) via `canvas.outline('K')`, then `canvas.selout('K','@')`
   to lighten the lit top/left edge. Do NOT anti-alias the *exterior* silhouette
   (backgrounds vary — it would clash); AA/selout **internal** edges only.
4. **Texture & detail via loops.** Brick courses, awning stripes, shelf goods,
   plaster lines, wood grain — draw in `for` loops. Add believable specifics
   (window reflections, product silhouettes, name tags, folds).
5. **Dither** (`dither`) to soften a gradient step; **catch-lights** (`'#'`) on
   eyes/glass/metal; **soft ground shadow** (`shadow`, alpha color `'-'`).
6. **Cohesion.** One palette (`kArtPal`), one light direction, consistent outline
   weight across every sprite.

## Workflow

1. Add/confirm material ramps in `kArtPal` (single-char keys, dark→light).
2. Write a `_buildX()` returning `canvas.toSprite(kArtPal)`; compose big shapes
   first, then shading, then detail, then `outline`, then `shadow`.
3. Register the sprite in `test/pixel_sprites_test.dart` (width + palette
   invariants) and in the contact sheet / a large preview golden.
4. `flutter test test/pixel_sprites_test.dart --update-goldens`, **Read the PNG**,
   iterate on proportions/shading. Repeat until it reads at target size.
5. Wire into screens with `PixelView(sprite, height/pixelSize)`; keep layout
   sized to the sprite's native pixels so scaling stays integer/crisp.

## Honest ceiling

Hand-coded pixel art reaches solid semi-pro quality — excellent for
buildings/props/icons, good for characters. True top-tier *illustrated* raster
art needs a diffusion pipeline (not available in this coding env); if that bar is
required, generate sprite sheets externally and integrate them as image assets
instead — but the default here is all-code for determinism + zero asset weight.

## Review checklist (game-visual-qa aligns)

- [ ] ≥3 tones per material, top-left light consistent
- [ ] silhouette reads at final on-screen size (check the golden at that scale)
- [ ] outline weight uniform; no stray pixels/spikes
- [ ] detail present (texture/reflection/props), not flat blocks
- [ ] palette shared (`kArtPal`); width+palette tests pass
