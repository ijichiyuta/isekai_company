import 'package:isekai_core/isekai_core.dart';
import 'package:isekai_headless/isekai_headless.dart';

/// Dev tool: economy calibration snapshot. For each seed, runs steady/attack/
/// idle full lives and reports the §10.2 funds curve, rank-4 reach, bankruptcy,
/// and the AC-10 manual-vs-idle advantage — the numbers P1 tunes toward.
///
///   dart run bin/calibrate.dart
const _cp = [400, 1000, 1800, 2600];

({List<int> curve, int finalFunds, int rank, String end, int revPerWk})
    _run(Balance b, BotFactory mk, int seed) {
  final s = GameState.initial(b, seed);
  final e = Engine(b);
  final bot = mk(b);
  final curve = <int>[];
  var ci = 0;
  while (s.alive) {
    e.tick(s, bot.decide(s));
    while (ci < _cp.length && s.week >= _cp[ci]) {
      curve.add(s.funds);
      ci++;
    }
  }
  for (; ci < _cp.length; ci++) {
    curve.add(s.funds);
  }
  return (
    curve: curve,
    finalFunds: s.funds,
    rank: s.rank,
    end: s.endReason,
    revPerWk: s.week == 0 ? 0 : s.totalRevenue ~/ s.week,
  );
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
  return '$n';
}

void main() {
  // Events ON — matches the app (§3.7) and the --gate measurement. Events boost
  // fame/funds, which igniting the demand loop earlier, so this is the config
  // AC-09 actually scores against.
  final b = loadBalanceFromDir('../../assets/balance',
      withEvents: true, withMarket: true);
  const seeds = [1, 2, 999];
  print('§10.2 checkpoints (ticks): $_cp');
  for (final seed in seeds) {
    final st = _run(b, (x) => SteadyBot(x), seed);
    print('seed $seed steady: curve=[${st.curve.map(_fmt).join(", ")}] '
        'final=${_fmt(st.finalFunds)} rank=${st.rank} end=${st.end}');
  }
  // Aggregate rank-4 reach + bankruptcy over a wider sample.
  var steadyR4 = 0, steadyBankrupt = 0, attackBankrupt = 0;
  var attackRev = <int>[], idleRev = <int>[];
  const n = 60;
  for (var i = 0; i < n; i++) {
    final st = _run(b, (x) => SteadyBot(x), 1 + i);
    if (st.rank >= 4) steadyR4++;
    if (st.end == 'bankrupt') steadyBankrupt++;
    final at = _run(b, (x) => AttackBot(x), 1 + i);
    if (at.end == 'bankrupt') attackBankrupt++;
    attackRev.add(at.revPerWk);
    idleRev.add(_run(b, (x) => IdleBot(x), 1 + i).revPerWk);
  }
  attackRev.sort();
  idleRev.sort();
  final aMed = attackRev[n ~/ 2], iMed = idleRev[n ~/ 2];
  final adv = iMed == 0 ? 0 : (aMed - iMed) * 100 ~/ iMed;
  print('--- over $n seeds ---');
  print('steady rank4 reach: ${steadyR4 * 100 ~/ n}%  (AC-08 target >=80%)');
  print('steady bankrupt: ${steadyBankrupt * 100 ~/ n}%  (AC-07 <5%)');
  print('attack bankrupt: ${attackBankrupt * 100 ~/ n}%  (AC-07 <30%)');
  print('AC-10 attack vs idle rev/wk: +$adv%  (target +10..20%)');
}
