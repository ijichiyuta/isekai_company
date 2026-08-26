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
    // AC-08 (soft): steady 御用達(rank4) reach ≥80%.
    GateResult('AC-08', 'steady 御用達到達%', '${reachPct(steady, 4)}%', '≥80%',
        reachPct(steady, 4) >= 80, false),
    // AC-10 (soft): attack vs idle weekly revenue advantage +10..20%
    // (structurally unreachable until #15/#16 automation in M3).
    GateResult('AC-10', 'attack vs idle rev/wk', '+$advPct%', '+10..20%',
        advPct >= 10 && advPct <= 20, false),
  ];
  return GateReport(results, balance.contentHash);
}
