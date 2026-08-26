import 'dart:io';

import 'package:isekai_core/isekai_core.dart';
import 'package:isekai_headless/isekai_headless.dart';

/// Headless runner (requirements §18).
///
/// Usage (from packages/headless):
///   dart run bin/run.dart --lives 1000 --seed 1 --verify-replay
///   dart run bin/run.dart --bot attack --lives 500
///   dart run bin/run.dart --compare --lives 500        # all 4 bots side by side
///   dart run bin/run.dart --lives 10000 --csv nightly.csv
void main(List<String> args) {
  var balanceDir = 'assets/balance';
  var lives = 10;
  var seed = 42;
  var verify = false;
  var hashOnly = false;
  var compare = false;
  var gate = false;
  var botName = 'steady';
  String? csvPath;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--balance':
        balanceDir = args[++i];
      case '--lives':
        lives = int.parse(args[++i]);
      case '--seed':
        seed = int.parse(args[++i]);
      case '--bot':
        botName = args[++i];
      case '--compare':
        compare = true;
      case '--gate':
        gate = true;
      case '--verify-replay':
        verify = true;
      case '--hash-only':
        hashOnly = true;
      case '--csv':
        csvPath = args[++i];
      default:
        stderr.writeln('unknown arg: ${args[i]}');
        exit(2);
    }
  }

  if (!Directory(balanceDir).existsSync() &&
      Directory('../../$balanceDir').existsSync()) {
    balanceDir = '../../$balanceDir';
  }
  final balance = loadBalanceFromDir(balanceDir);

  if (compare) {
    _runCompare(balance, lives, seed);
    return;
  }

  if (gate) {
    // Gates measure the REAL game, so load events (reward pacing / AC-05).
    final gateBalance = loadBalanceFromDir(balanceDir, withEvents: true);
    final report = evaluateGate(gateBalance, lives: lives, seedBase: seed);
    print('=== balance gate (${lives} lives/bot, balance ${report.balanceHash}) ===');
    print('AC     metric                     actual        threshold        '
        'hard  result');
    for (final r in report.results) {
      print('${r.ac.padRight(6)} ${r.metric.padRight(26)} '
          '${r.actual.padRight(13)} ${r.threshold.padRight(16)} '
          '${(r.hard ? "H" : "-").padRight(5)} ${r.pass ? "PASS" : "FAIL"}');
    }
    if (report.ok) {
      print('GATE: OK (all hard gates pass)');
    } else {
      print('GATE: FAIL (a hard gate failed)');
      exit(1);
    }
    return;
  }

  final factory = botFactoryByName(botName);

  if (verify) {
    // Determinism must hold for every bot, not just steady.
    for (final name in botRegistry.keys) {
      final err = verifyReplay(balance, seed, botFactory: botRegistry[name]);
      if (err != null) {
        stderr.writeln('REPLAY MISMATCH (AC-02) for bot=$name: $err');
        exit(1);
      }
    }
    print('replay determinism: OK for all ${botRegistry.length} bots '
        '(seed=$seed, balance=${balance.contentHash})');
  }

  final watch = Stopwatch()..start();
  final stats = <LifeStats>[];
  var totalTicks = 0;
  for (var i = 0; i < lives; i++) {
    final s = runLife(balance, seed + i, botFactory: factory);
    stats.add(s);
    totalTicks += s.weeks;
  }
  watch.stop();

  if (hashOnly) {
    for (final s in stats) {
      print('${s.seed}:${s.finalHash}');
    }
    return;
  }

  if (csvPath != null) {
    final sb = StringBuffer()..writeln(LifeStats.csvHeader);
    for (final s in stats) {
      sb.writeln(s.toCsvRow());
    }
    File(csvPath).writeAsStringSync(sb.toString());
  }

  _printSummary(botName, stats, balance.contentHash, watch, totalTicks, lives);
}

void _printSummary(String bot, List<LifeStats> stats, String hash,
    Stopwatch watch, int totalTicks, int lives) {
  final s = _Summary(stats);
  final elapsedMs = watch.elapsedMilliseconds;
  final usPerTick = totalTicks == 0 ? 0.0 : elapsedMs * 1000 / totalTicks;
  print('bot=$bot lives=$lives balance=$hash');
  print('bankrupt: ${s.bankrupt}/$lives '
      '(${(s.bankrupt * 100 / lives).toStringAsFixed(1)}%)');
  print('median funds: ${s.medianFunds} G / avg rank: '
      '${s.avgRank.toStringAsFixed(2)} / avg discoveries: '
      '${s.avgDiscoveries.toStringAsFixed(1)}');
  print('median revenue/week: ${s.medianRevPerWeek} G');
  print('elapsed: ${elapsedMs}ms, ${usPerTick.toStringAsFixed(2)}us/tick '
      '(AC-03 budget: <= 1000us/tick)');
}

void _runCompare(Balance balance, int lives, int seed) {
  print('=== bot comparison ($lives lives/bot, seed base $seed, '
      'balance ${balance.contentHash}) ===');
  print('bot         bankrupt%  medianFunds   avgRank  medRev/wk');
  final rev = <String, int>{};
  for (final name in botRegistry.keys) {
    final stats = <LifeStats>[];
    for (var i = 0; i < lives; i++) {
      stats.add(runLife(balance, seed + i, botFactory: botRegistry[name]));
    }
    final s = _Summary(stats);
    rev[name] = s.medianRevPerWeek;
    print('${name.padRight(11)} '
        '${(s.bankrupt * 100 / lives).toStringAsFixed(1).padLeft(7)}  '
        '${s.medianFunds.toString().padLeft(12)}  '
        '${s.avgRank.toStringAsFixed(2).padLeft(7)}  '
        '${s.medianRevPerWeek.toString().padLeft(8)}');
  }
  // AC-10 read: 攻め型 vs 放置型 weekly profit-rate advantage.
  final attack = rev['attack'] ?? 0;
  final idle = rev['idle'] ?? 0;
  if (idle > 0) {
    final adv = ((attack - idle) * 100 / idle);
    print('AC-10 read: attack vs idle revenue/week advantage = '
        '${adv.toStringAsFixed(1)}% (target +10..20%)');
  }
}

class _Summary {
  late final int bankrupt;
  late final int medianFunds;
  late final double avgRank;
  late final double avgDiscoveries;
  late final int medianRevPerWeek;

  _Summary(List<LifeStats> stats) {
    bankrupt = stats.where((s) => s.endReason == 'bankrupt').length;
    final funds = stats.map((s) => s.funds).toList()..sort();
    medianFunds = funds[funds.length ~/ 2];
    final rev = stats.map((s) => s.revenuePerWeek).toList()..sort();
    medianRevPerWeek = rev[rev.length ~/ 2];
    avgRank = stats.fold<int>(0, (a, s) => a + s.rank) / stats.length;
    avgDiscoveries =
        stats.fold<int>(0, (a, s) => a + s.discoveries) / stats.length;
  }
}
