/// The entire mutable simulation state. Everything needed for a bit-identical
/// replay lives here (including RNG stream states with draw counters).
/// Collections are Lists indexed by entity id — no HashMap/HashSet in core
/// (requirements §2.2 rule 2).
library;

import 'balance.dart';
import 'hash.dart';
import 'meta.dart';
import 'money.dart';
import 'rng.dart';

int _clampTo(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

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

  // 魂の記憶 economy modifiers (M3 P2, §8.4): persistent per-life bonuses set by
  // GameState.fromMeta. Default 0 = no effect (byte-identical to a meta-less
  // life). productionBonus scales capacity, salesBonus scales the demand pool,
  // orderDiscount reduces material order cost — all in percent (x1).
  int productionBonusX100;
  int salesBonusX100;
  int orderDiscountX100;

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
    required this.productionBonusX100,
    required this.salesBonusX100,
    required this.orderDiscountX100,
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
        productionBonusX100: 0,
        salesBonusX100: 0,
        orderDiscountX100: 0,
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

  /// Start a life with the 魂の記憶 [meta] applied as initial-state modifiers
  /// (§8.4). Deterministic: modifiers are summed in unlock-id order, ADD phase
  /// (funds/employee/rank/equip/quality) BEFORE the MULTIPLY phase (funds %),
  /// so the result never depends on iteration order (audit R5). App-only — the
  /// headless determinism baseline uses [GameState.initial] (no meta); a
  /// headless reference to fromMeta is a CI failure (tool/check_forbidden.sh).
  ///
  /// Wired mod types: start_funds/employee/rank + equip/quality start levels +
  /// funds %, and the per-life economy multipliers (production/sales/order).
  /// The remaining mod types (auto_*, race_*, trend/decay/turnover/offline/
  /// hard_mode/hint/reveal/speed3) are feature-gated — tracked as unlocked
  /// (queryable via MetaReader) but with no effect until their feature exists
  /// (see functionalModTypes). This keeps the paywall honest.
  factory GameState.fromMeta(Balance b, int seed, MetaState meta,
      {int allowedBandMax = 1, int lifeNumber = 1}) {
    final s = GameState.initial(b, seed,
        allowedBandMax: allowedBandMax, lifeNumber: lifeNumber);
    var addFunds = 0, addEmp = 0, addRank = 0, addEquip = 0, addQuality = 0;
    var fundsPct = 0, prod = 0, sales = 0, order = 0, grantRecipes = 0;
    for (final u in b.unlocks) {
      final lvl = meta.levelOf(u.id);
      if (lvl <= 0) continue;
      switch (u.modType) {
        case 'start_funds':
          addFunds += u.modValue * lvl;
        case 'start_employee':
          addEmp += u.modValue * lvl;
        case 'start_rank':
          addRank += u.modValue * lvl;
        case 'equip_start_level':
          addEquip += u.modValue * lvl;
        case 'quality_start_star':
          addQuality += u.modValue * lvl;
        case 'start_funds_pct':
          fundsPct += u.modValue * lvl;
        case 'production_bonus':
          prod += u.modValue * lvl;
        case 'sales_bonus':
          sales += u.modValue * lvl;
        case 'order_discount':
          order += u.modValue * lvl;
        case 'grant_recipes':
          grantRecipes += u.modValue * lvl;
        default:
          break; // feature-gated; no effect until its feature exists
      }
    }
    // 基本レシピの継承 (§8.4 #5): pre-discover the first N band-1 staples so 2周目
    // starts with a working product line. Discovered (not invented) — no bonus.
    if (grantRecipes > 0) {
      var granted = 0;
      for (final r in b.recipes) {
        if (granted >= grantRecipes) break;
        if (r.band == 1 && !r.invention && !s.discovered[r.id]) {
          s.discovered[r.id] = true;
          s.discoveries++;
          granted++;
        }
      }
    }
    // ADD phase, each clamped to its valid range.
    s.funds = clampCap(s.funds + addFunds);
    s.employees = _clampTo(s.employees + addEmp, 0, b.economy.maxEmployees);
    s.rank = _clampTo(s.rank + addRank, 0, b.ranks.length - 1);
    s.equipmentLevel =
        _clampTo(s.equipmentLevel + addEquip, 0, b.economy.equipMaxLevel);
    s.qualityStar = _clampTo(
        s.qualityStar + addQuality, 0, b.economy.qualityMultX100.length - 1);
    s.productionBonusX100 = prod;
    s.salesBonusX100 = sales;
    // Order discount can't exceed 100% (never pay negative for materials).
    s.orderDiscountX100 = _clampTo(order, 0, 100);
    // MULTIPLY phase (AFTER add): initial-funds % boost (§8.4 #21, infinite).
    if (fundsPct != 0) s.funds = clampCap(s.funds * (100 + fundsPct) ~/ 100);
    return s;
  }

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
        if (productionBonusX100 != 0) 'production_bonus': productionBonusX100,
        if (salesBonusX100 != 0) 'sales_bonus': salesBonusX100,
        if (orderDiscountX100 != 0) 'order_discount': orderDiscountX100,
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
        productionBonusX100: (m['production_bonus'] as int?) ?? 0,
        salesBonusX100: (m['sales_bonus'] as int?) ?? 0,
        orderDiscountX100: (m['order_discount'] as int?) ?? 0,
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
