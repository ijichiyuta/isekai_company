/// The entire mutable simulation state. Everything needed for a bit-identical
/// replay lives here (including RNG stream states with draw counters).
/// Collections are Lists indexed by entity id — no HashMap/HashSet in core
/// (requirements §2.2 rule 2).
library;

import 'balance.dart';
import 'hash.dart';
import 'rng.dart';

class GameState {
  int week;
  int funds;
  int fame;
  int rank;
  int employees;
  int negativeStreak;
  bool alive;
  String endReason; // '', 'lifespan', 'bankrupt'
  int allowedBandMax; // recipe bands discoverable this life (meta progression)

  final List<int> materialStock; // by material id
  final List<int> productStock; // by recipe id
  final List<bool> discovered; // by recipe id

  // Cumulative counters (life stats / reward pacing).
  int discoveries;
  int inventions;
  int rankUps;
  int totalRevenue;
  int rewardEvents;

  final RngStreams rng;

  GameState.raw({
    required this.week,
    required this.funds,
    required this.fame,
    required this.rank,
    required this.employees,
    required this.negativeStreak,
    required this.alive,
    required this.endReason,
    required this.allowedBandMax,
    required this.materialStock,
    required this.productStock,
    required this.discovered,
    required this.discoveries,
    required this.inventions,
    required this.rankUps,
    required this.totalRevenue,
    required this.rewardEvents,
    required this.rng,
  });

  factory GameState.initial(Balance b, int seed, {int allowedBandMax = 1}) =>
      GameState.raw(
        week: 0,
        funds: b.economy.startFunds,
        fame: 0,
        rank: 0,
        employees: 0,
        negativeStreak: 0,
        alive: true,
        endReason: '',
        allowedBandMax: allowedBandMax,
        materialStock: List<int>.filled(b.materials.length, 0),
        productStock: List<int>.filled(b.recipes.length, 0),
        discovered: List<bool>.filled(b.recipes.length, false),
        discoveries: 0,
        inventions: 0,
        rankUps: 0,
        totalRevenue: 0,
        rewardEvents: 0,
        rng: RngStreams.seeded(seed),
      );

  Map<String, dynamic> toJson() => {
        'week': week,
        'funds': funds,
        'fame': fame,
        'rank': rank,
        'employees': employees,
        'negative_streak': negativeStreak,
        'alive': alive,
        'end_reason': endReason,
        'allowed_band_max': allowedBandMax,
        // Defensive copies: a snapshot must not alias the live lists, or a
        // later tick's in-place mutation would corrupt it (snapshot+journal
        // save, requirements §17.1). fromJson already copies on the way in.
        'material_stock': List<int>.of(materialStock),
        'product_stock': List<int>.of(productStock),
        'discovered': List<bool>.of(discovered),
        'discoveries': discoveries,
        'inventions': inventions,
        'rank_ups': rankUps,
        'total_revenue': totalRevenue,
        'reward_events': rewardEvents,
        'rng': rng.toJson(),
      };

  factory GameState.fromJson(Map<String, dynamic> m) => GameState.raw(
        week: m['week'] as int,
        funds: m['funds'] as int,
        fame: m['fame'] as int,
        rank: m['rank'] as int,
        employees: m['employees'] as int,
        negativeStreak: m['negative_streak'] as int,
        alive: m['alive'] as bool,
        endReason: m['end_reason'] as String,
        allowedBandMax: m['allowed_band_max'] as int,
        materialStock: (m['material_stock'] as List).cast<int>().toList(),
        productStock: (m['product_stock'] as List).cast<int>().toList(),
        discovered: (m['discovered'] as List).cast<bool>().toList(),
        discoveries: m['discoveries'] as int,
        inventions: m['inventions'] as int,
        rankUps: m['rank_ups'] as int,
        totalRevenue: m['total_revenue'] as int,
        rewardEvents: m['reward_events'] as int,
        rng: RngStreams.fromJson(m['rng'] as Map<String, dynamic>),
      );

  /// Canonical hash of the full state — the replay-equality check (AC-02).
  int stateHash() => fnv1a64(canonicalJson(toJson()));
}
