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

  // Reinvestment drivers (M3 P1, §10.2 economy). Default 0 = no effect, so a
  // balance without the equip/quality keys behaves byte-identically to pre-M3
  // (existing determinism tests unchanged). equipmentLevel scales weekly
  // capacity; qualityStar scales sale price.
  int equipmentLevel;
  int qualityStar;

  final List<int> materialStock; // by material id
  final List<int> productStock; // by recipe id
  final List<bool> discovered; // by recipe id

  // Cumulative counters (life stats / reward pacing).
  int discoveries;
  int inventions;
  int rankUps;
  int totalRevenue;
  int rewardEvents;

  // Event state (requirements §3.7). ALL default here, and toJson omits any
  // field at its default, so an events-less world (headless) serializes exactly
  // as before events existed — keeping AC-01/02/03 hashes unchanged (audit A-D2).
  int lifeNumber; // 1 by default; cycle events need >=2
  int pendingEventId; // -1 = none pending
  bool royalCleared; // 御用達 gate: royal contract accepted
  int eventDry; // ticks since the last event fired (pity timer)
  final List<int> firedThisLife; // event ids fired this life (no repeat)

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
    required this.equipmentLevel,
    required this.qualityStar,
    required this.materialStock,
    required this.productStock,
    required this.discovered,
    required this.discoveries,
    required this.inventions,
    required this.rankUps,
    required this.totalRevenue,
    required this.rewardEvents,
    required this.lifeNumber,
    required this.pendingEventId,
    required this.royalCleared,
    required this.eventDry,
    required this.firedThisLife,
    required this.rng,
  });

  factory GameState.initial(Balance b, int seed,
          {int allowedBandMax = 1, int lifeNumber = 1}) =>
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
        equipmentLevel: 0,
        qualityStar: 0,
        materialStock: List<int>.filled(b.materials.length, 0),
        productStock: List<int>.filled(b.recipes.length, 0),
        discovered: List<bool>.filled(b.recipes.length, false),
        discoveries: 0,
        inventions: 0,
        rankUps: 0,
        totalRevenue: 0,
        rewardEvents: 0,
        lifeNumber: lifeNumber,
        pendingEventId: -1,
        royalCleared: false,
        eventDry: 0,
        firedThisLife: <int>[],
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
        // Emitted only when non-default so a balance without equip/quality keys
        // hashes identically to the pre-M3 build (mirrors the event fields).
        if (equipmentLevel != 0) 'equipment_level': equipmentLevel,
        if (qualityStar != 0) 'quality_star': qualityStar,
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
        // Event fields: emitted ONLY when non-default so an events-less world
        // hashes identically to the pre-events build (audit A-D2).
        if (lifeNumber != 1) 'life_number': lifeNumber,
        if (pendingEventId != -1) 'pending_event': pendingEventId,
        if (royalCleared) 'royal_cleared': true,
        if (eventDry != 0) 'event_dry': eventDry,
        if (firedThisLife.isNotEmpty) 'fired_events': List<int>.of(firedThisLife),
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
        equipmentLevel: (m['equipment_level'] as int?) ?? 0,
        qualityStar: (m['quality_star'] as int?) ?? 0,
        materialStock: (m['material_stock'] as List).cast<int>().toList(),
        productStock: (m['product_stock'] as List).cast<int>().toList(),
        discovered: (m['discovered'] as List).cast<bool>().toList(),
        discoveries: m['discoveries'] as int,
        inventions: m['inventions'] as int,
        rankUps: m['rank_ups'] as int,
        totalRevenue: m['total_revenue'] as int,
        rewardEvents: m['reward_events'] as int,
        // Event fields default when absent (v1 backward compat, audit A-D2).
        lifeNumber: (m['life_number'] as int?) ?? 1,
        pendingEventId: (m['pending_event'] as int?) ?? -1,
        royalCleared: (m['royal_cleared'] as bool?) ?? false,
        eventDry: (m['event_dry'] as int?) ?? 0,
        firedThisLife:
            ((m['fired_events'] as List?)?.cast<int>().toList()) ?? <int>[],
        rng: RngStreams.fromJson(m['rng'] as Map<String, dynamic>),
      );

  /// Canonical hash of the full state — the replay-equality check (AC-02).
  int stateHash() => fnv1a64(canonicalJson(toJson()));
}
