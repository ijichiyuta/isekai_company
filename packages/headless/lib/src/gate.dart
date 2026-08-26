/// Balance-gate evaluation (requirements §18, AC-04〜10). Runs the bot suite and
/// checks the acceptance conditions. Per the M2 plan audit (docs/m2-plan-audit.md):
///   HARD (block CI): AC-04, AC-07  (+ AC-05 once events land)
///   SOFT (report only): AC-05 (pre-events), AC-06, AC-08, AC-09, AC-10 —
///   these depend on content/events/M3 automation not yet present.
library;

import 'package:isekai_core/isekai_core.dart';

import 'bots.dart';
import 'runner.dart';
import 'stats.dart';

class GateResult {
  final String ac;
  final String metric;
  final String actual;
  final String threshold;
  final bool pass;
  final bool hard; // hard gates fail CI; soft gates only report
  const GateResult(this.ac, this.metric, this.actual, this.threshold, this.pass,
      this.hard);
}

class GateReport {
  final List<GateResult> results;
  final String balanceHash;
  const GateReport(this.results, this.balanceHash);

  /// CI fails only if a HARD gate failed.
  bool get ok => !results.any((r) => r.hard && !r.pass);
}

GateReport evaluateGate(Balance balance, {int lives = 300, int seedBase = 1}) {
  List<LifeStats> run(String bot, {int band = 1}) => [
        for (var i = 0; i < lives; i++)
          runLife(balance, seedBase + i,
              botFactory: botRegistry[bot], allowedBandMax: band),
      ];

  final steady = run('steady');
  final attack = run('attack');
  final idle = run('idle');

  int bankruptPct(List<LifeStats> xs) =>
      xs.where((s) => s.endReason == 'bankrupt').length * 100 ~/ xs.length;
  int reachPct(List<LifeStats> xs, int rank) =>
      xs.where((s) => s.rank >= rank).length * 100 ~/ xs.length;
  int medianRevPerWeek(List<LifeStats> xs) =>
      median([for (final s in xs) s.weeks == 0 ? 0 : s.totalRevenue ~/ s.weeks]);

  final band1Recipes = balance.recipes.where((r) => r.band == 1).length;
  final medDiscoveries = median([for (final s in steady) s.discoveries]);
  final medP50 = median([for (final s in steady) s.intervals.p50GapTicks]);
  final medP90 = median([for (final s in steady) s.intervals.p90GapTicks]);
  final maxGap =
      [for (final s in steady) s.intervals.maxGapTicks].reduce((a, b) => a > b ? a : b);
  final attackRev = medianRevPerWeek(attack);
  final idleRev = medianRevPerWeek(idle);
  final advPct = idleRev == 0 ? 0 : (attackRev - idleRev) * 100 ~/ idleRev;

  // AC-05 becomes HARD once events exist to fill reward gaps (audit C-D4).
  final eventsPresent = balance.events.isNotEmpty;

  final results = <GateResult>[
    // AC-04 (hard): 周1 discovery count in [min(35,band1), band1].
    GateResult(
      'AC-04',
      '周1 median discoveries',
      '$medDiscoveries',
      '$band1Recipes 種中 ${band1Recipes < 35 ? band1Recipes : 35}以上',
      medDiscoveries >= (band1Recipes < 35 ? band1Recipes : 35),
      true,
    ),
    // AC-05: reward pacing. Hard only when events are present.
    GateResult(
      'AC-05',
      'p50/p90/maxGap (ticks)',
      '$medP50/$medP90/$maxGap',
      'p50≤26 p90≤60 maxGap≤120',
      medP50 <= 26 && medP90 <= 60 && maxGap <= 120,
      eventsPresent,
    ),
    // AC-07 (hard): bankruptcy — steady <5%, attack <30%.
    GateResult('AC-07', 'bankrupt% steady', '${bankruptPct(steady)}%', '<5%',
        bankruptPct(steady) < 5, true),
    GateResult('AC-07', 'bankrupt% attack', '${bankruptPct(attack)}%', '<30%',
        bankruptPct(attack) < 30, true),
    // AC-08 (HARD as of M3 P1): steady 御用達(rank4) reach ≥80%. Made hard once
    // the reinvestment economy (equipment×quality) achieved it — steady reaches
    // rank 4 at ~100% with attack bankruptcy <30% across seeds (docs/adr/
    // 0002). Locks the achievement against regression.
    GateResult('AC-08', 'steady 御用達到達%', '${reachPct(steady, 4)}%', '≥80%',
        reachPct(steady, 4) >= 80, true),
    // AC-10 (soft): attack vs idle weekly revenue advantage +10..20%
    // (structurally unreachable until #15/#16 automation in M3).
    GateResult('AC-10', 'attack vs idle rev/wk', '+$advPct%', '+10..20%',
        advPct >= 10 && advPct <= 20, false),
    // AC-09 (soft): the §10.2 funds curve within ±50% at checkpoints. Measured
    // honestly (not hidden) — currently far off, which is the economy-shape
    // problem carried to M3 (the near-geometric §10.2 curve vs the capacity-
    // limited linear economy). Reported so the deviation is visible.
    _ac09(balance, lives, seedBase),
  ];
  return GateReport(results, balance.contentHash);
}

// §10.2 checkpoints: 10/25/45/65 min → ticks 400/1000/1800/2600. Targets are
// the REVISED §10.2 curve (M3 P1 / ADR-0002): the achievable steady trajectory
// under the equipment×quality reinvestment economy. The original near-geometric
// targets (2000/40000/800000/15000000) were proven unreachable (fame-loop ρ is
// constant, §10.2 required decreasing ρ — docs/m3-plan-audit.md); the revised
// curve tracks the original closely at 1000/2600 and reaches 御用達 (15M) as a
// late-game milestone. Targets are median funds across seeds; the default
// --gate uses 10 lives, where event RNG can swing a checkpoint ±40% — the ±50%
// band absorbs it, and 300+ lives converge near the targets (AC-09 is soft).
const _curveTicks = [400, 1000, 1800, 2600];
const _curveTargets = [15500, 275000, 6000000, 38000000];

GateResult _ac09(Balance balance, int lives, int seedBase) {
  final steady = botRegistry['steady']!;
  // Median funds at each checkpoint across lives.
  final samplesByCp = List.generate(_curveTicks.length, (_) => <int>[]);
  for (var i = 0; i < lives; i++) {
    final s = GameState.initial(balance, seedBase + i);
    final engine = Engine(balance);
    final bot = steady(balance);
    var ci = 0;
    while (s.alive) {
      engine.tick(s, bot.decide(s));
      while (ci < _curveTicks.length && s.week >= _curveTicks[ci]) {
        samplesByCp[ci].add(s.funds);
        ci++;
      }
    }
    for (; ci < _curveTicks.length; ci++) {
      samplesByCp[ci].add(s.funds);
    }
  }
  var worstRatioPct = 100; // 100 = on target
  final parts = <String>[];
  for (var c = 0; c < _curveTicks.length; c++) {
    final med = median(samplesByCp[c]);
    final target = _curveTargets[c];
    final ratioPct = target == 0 ? 100 : med * 100 ~/ target;
    parts.add('${_curveTicks[c]}w:${ratioPct}%');
    if ((ratioPct - 100).abs() > (worstRatioPct - 100).abs()) {
      worstRatioPct = ratioPct;
    }
  }
  final within = (worstRatioPct - 100).abs() <= 50;
  return GateResult('AC-09', 'curve vs §10.2 (${parts.join(" ")})',
      'worst ${worstRatioPct}%', '±50%', within, false);
}
