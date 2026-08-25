/// Currency is always int64 G. Rates are basis points (1/10,000) or
/// x100 fixed-point multipliers. No floating point anywhere in core
/// (requirements §2.2 rule 1).
library;

/// value × (bp / 10,000), truncated toward zero.
int applyBp(int value, int bp) => value * bp ~/ 10000;

/// value × (multX100 / 100), truncated toward zero.
int applyX100(int value, int multX100) => value * multX100 ~/ 100;
