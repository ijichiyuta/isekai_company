/// PCG32 PRNG, self-implemented (no dart:math — requirements §2.2 rule 5).
/// Streams are split per system; each stream serializes its state and draw
/// counter into the save so replays stay bit-identical after load.
library;

class Pcg32 {
  int _state;
  final int _inc;
  int drawCount;

  Pcg32.raw(this._state, this._inc, this.drawCount);

  /// Standard PCG32 seeding. [streamId] selects an independent sequence.
  factory Pcg32(int seed, int streamId) {
    final rng = Pcg32.raw(0, (streamId << 1) | 1, 0);
    rng._advance();
    rng._state = rng._state + seed;
    rng._advance();
    return rng;
  }

  void _advance() {
    _state = _state * 6364136223846793005 + _inc;
  }

  int nextUint32() {
    final old = _state;
    _advance();
    drawCount++;
    final xorshifted = (((old >>> 18) ^ old) >>> 27) & 0xFFFFFFFF;
    final rot = old >>> 59;
    return ((xorshifted >>> rot) | (xorshifted << ((32 - rot) & 31))) &
        0xFFFFFFFF;
  }

  /// Uniform-ish int in [0, bound). Modulo bias is accepted: determinism is
  /// the requirement, statistical perfection is not (gameplay RNG).
  int nextInt(int bound) => nextUint32() % bound;

  Map<String, dynamic> toJson() =>
      {'state': _state, 'inc': _inc, 'draws': drawCount};

  factory Pcg32.fromJson(Map<String, dynamic> m) =>
      Pcg32.raw(m['state'] as int, m['inc'] as int, m['draws'] as int);
}

/// Per-system RNG streams (requirements §2.2 rule 5).
class RngStreams {
  final Pcg32 economy;
  final Pcg32 discovery;
  final Pcg32 events;
  final Pcg32 employees;

  RngStreams({
    required this.economy,
    required this.discovery,
    required this.events,
    required this.employees,
  });

  factory RngStreams.seeded(int masterSeed) => RngStreams(
        economy: Pcg32(masterSeed, 1),
        discovery: Pcg32(masterSeed, 2),
        events: Pcg32(masterSeed, 3),
        employees: Pcg32(masterSeed, 4),
      );

  Map<String, dynamic> toJson() => {
        'economy': economy.toJson(),
        'discovery': discovery.toJson(),
        'events': events.toJson(),
        'employees': employees.toJson(),
      };

  factory RngStreams.fromJson(Map<String, dynamic> m) => RngStreams(
        economy: Pcg32.fromJson(m['economy'] as Map<String, dynamic>),
        discovery: Pcg32.fromJson(m['discovery'] as Map<String, dynamic>),
        events: Pcg32.fromJson(m['events'] as Map<String, dynamic>),
        employees: Pcg32.fromJson(m['employees'] as Map<String, dynamic>),
      );
}
