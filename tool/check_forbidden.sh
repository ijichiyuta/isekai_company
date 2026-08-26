#!/usr/bin/env bash
# Enforces the determinism rules of docs/requirements.md §2.2 in the core:
# no IO, no Flutter, no floating point, no wall clock, no hash collections.
# Banned tokens may appear in whole-line comments (///, //) only.
set -euo pipefail
cd "$(dirname "$0")/.."

pattern='dart:io|dart:ui|dart:html|package:flutter|dart:math|\bdouble\b|\bDateTime\b|\bStopwatch\b|\bHashMap\b|\bHashSet\b'

violations=$(grep -rnE "$pattern" packages/core/lib | grep -vE ':[0-9]+: *(///|//)' || true)

if [ -n "$violations" ]; then
  echo "$violations"
  echo "NG: forbidden token(s) in packages/core/lib (requirements §2.2)"
  exit 1
fi
echo "OK: core is clean (no IO / Flutter / floating point / wall clock / hash collections)"

# The headless determinism baseline must stay meta-less: GameState.fromMeta
# applies 魂の記憶 modifiers (app-only), which would diverge the cross-arch hash
# comparison. Bots and the runner use GameState.initial only (M3 P2 / audit R6).
meta_use=$(grep -rnE '\bfromMeta\b' packages/headless/lib packages/headless/bin || true)
if [ -n "$meta_use" ]; then
  echo "$meta_use"
  echo "NG: headless references GameState.fromMeta (must use GameState.initial — audit R6)"
  exit 1
fi
echo "OK: headless is meta-less (no fromMeta — determinism baseline intact)"
