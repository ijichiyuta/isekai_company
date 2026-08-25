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
