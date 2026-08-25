import 'dart:io';

import 'package:isekai_headless/isekai_headless.dart';

/// Headless runner (requirements §18).
///
/// Usage (from repo root or packages/headless):
///   dart run bin/run.dart --balance ../../assets/balance \
///       --lives 200 --seed 1 --verify-replay [--csv out.csv] [--hash-only]
void main(List<String> args) {
  var balanceDir = 'assets/balance';
  var lives = 10;
  var seed = 42;
  var verify = false;
  var hashOnly = false;
  String? csvPath;

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--balance':
        balanceDir = args[++i];
      case '--lives':
        lives = int.parse(args[++i]);
      case '--seed':
        seed = int.parse(args[++i]);
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

  if (verify) {
    final error = verifyReplay(balance, seed);
    if (error != null) {
      stderr.writeln('REPLAY MISMATCH (AC-02 violated): $error');
      exit(1);
    }
    print('replay determinism: OK (seed=$seed, balance=${balance.contentHash})');
  }

  final watch = Stopwatch()..start();
  final stats = <LifeStats>[];
  var totalTicks = 0;
  for (var i = 0; i < lives; i++) {
    final s = runLife(balance, seed + i);
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

  final bankrupt = stats.where((s) => s.endReason == 'bankrupt').length;
  final sortedFunds = stats.map((s) => s.funds).toList()..sort();
  final medianFunds = sortedFunds[sortedFunds.length ~/ 2];
  final avgDiscoveries =
      stats.fold<int>(0, (a, s) => a + s.discoveries) / stats.length;
  final avgRank = stats.fold<int>(0, (a, s) => a + s.rank) / stats.length;
  final elapsedMs = watch.elapsedMilliseconds;
  final ticksPerSec =
      elapsedMs == 0 ? 0 : (totalTicks * 1000 / elapsedMs).round();
  final usPerTick =
      totalTicks == 0 ? 0 : (elapsedMs * 1000 / totalTicks);

  print('lives=$lives seedBase=$seed balance=${balance.contentHash}');
  print('bankrupt: $bankrupt/$lives '
      '(${(bankrupt * 100 / lives).toStringAsFixed(1)}%)');
  print('median final funds: $medianFunds G');
  print('avg discoveries: ${avgDiscoveries.toStringAsFixed(1)} / '
      'avg rank: ${avgRank.toStringAsFixed(2)}');
  print('elapsed: ${elapsedMs}ms, $ticksPerSec ticks/s, '
      '${usPerTick.toStringAsFixed(1)}us/tick '
      '(AC-03 budget: p95 <= 1000us/tick)');
  print('est. 1000 lives: '
      '${(elapsedMs / lives * 1000 / 1000).toStringAsFixed(1)}s');
}
