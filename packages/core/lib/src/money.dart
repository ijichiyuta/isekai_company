/// Currency is always int64 G. Rates are basis points (1/10,000) or
/// x100 fixed-point multipliers. No floating point anywhere in core
/// (requirements §2.2 rule 1).
library;

/// In-game value ceiling (requirements §10.5). Every accumulating quantity
/// (funds, fame, revenue, demand) is clamped to ±this so downstream integer
/// arithmetic can never silently wrap a 64-bit int.
const int gameValueCap = 1000000000000000; // 1e15

/// Clamp a magnitude to ±[gameValueCap].
int clampCap(int v) {
  if (v > gameValueCap) return gameValueCap;
  if (v < -gameValueCap) return -gameValueCap;
  return v;
}

/// value × (bp / 10,000), truncated toward zero, overflow-safe.
///
/// The multiplication is split via truncating-division so the intermediate
/// product stays well inside int64 even at the 1e15 cap: q ≤ 1e11 and bp is
/// bounded by balance (≤ a few thousand). Uses [num.remainder] (not `%`) so the
/// identity value == q*10000 + r holds for negative values, preserving
/// toward-zero rounding.
int applyBp(int value, int bp) {
  final v = clampCap(value);
  final q = v ~/ 10000;
  final r = v.remainder(10000);
  return q * bp + (r * bp ~/ 10000);
}

/// value × (multX100 / 100), truncated toward zero, overflow-safe.
int applyX100(int value, int multX100) {
  final v = clampCap(value);
  final q = v ~/ 100;
  final r = v.remainder(100);
  return q * multX100 + (r * multX100 ~/ 100);
}
