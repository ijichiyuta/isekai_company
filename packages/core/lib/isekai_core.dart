/// Isekai Company — deterministic simulation core (pure Dart).
///
/// Hard rules (docs/requirements.md §2.2, enforced by tool/check_forbidden.sh):
/// no Flutter, no dart:io / dart:ui, no dart:math, no double, no DateTime /
/// Stopwatch, no HashMap / HashSet. All state changes flow through [Engine.tick]
/// with an explicit command list; RNG is seeded PCG32 with per-system streams.
library;

export 'src/balance.dart';
export 'src/commands.dart';
export 'src/engine.dart';
export 'src/hash.dart';
export 'src/money.dart';
export 'src/rng.dart';
export 'src/save.dart';
export 'src/state.dart';
