import 'package:isekai_core/isekai_core.dart';

import 'bot.dart';
import 'steady_bot.dart';

class LifeStats {
  final int seed;
  final String bot;
  final int weeks;
  final int funds;
  final int fame;
  final int rank;
  final int discoveries;
  final int inventions;
  final int rankUps;
  final int rewardEvents;
  final int totalRevenue;
  final String endReason;
  final String finalHash;

  LifeStats({
    required this.seed,
    required this.bot,
    required this.weeks,
    required this.funds,
    required this.fame,
    required this.rank,
    required this.discoveries,
    required this.inventions,
    required this.rankUps,
    required this.rewardEvents,
    required this.totalRevenue,
    required this.endReason,
    required this.finalHash,
  });

  /// Weekly profit rate proxy for AC-10: lifetime revenue per lived week.
  int get revenuePerWeek => weeks == 0 ? 0 : totalRevenue ~/ weeks;

  String toCsvRow() =>
      '$seed,$bot,$weeks,$funds,$fame,$rank,$discoveries,$inventions,$rankUps,'
      '$rewardEvents,$totalRevenue,$endReason,$finalHash';

  static const csvHeader = 'seed,bot,weeks,funds,fame,rank,discoveries,'
      'inventions,rank_ups,reward_events,total_revenue,end_reason,final_hash';
}

LifeStats runLife(
  Balance balance,
  int seed, {
  Bot Function(Balance)? botFactory,
  int allowedBandMax = 1,
}) {
  final state =
      GameState.initial(balance, seed, allowedBandMax: allowedBandMax);
  final engine = Engine(balance);
  final bot = (botFactory ?? SteadyBot.new)(balance);
  while (state.alive) {
    engine.tick(state, bot.decide(state));
  }
  return LifeStats(
    seed: seed,
    bot: bot.name,
    weeks: state.week,
    funds: state.funds,
    fame: state.fame,
    rank: state.rank,
    discoveries: state.discoveries,
    inventions: state.inventions,
    rankUps: state.rankUps,
    rewardEvents: state.rewardEvents,
    totalRevenue: state.totalRevenue,
    endReason: state.endReason,
    finalHash: hashHex(state.stateHash()),
  );
}

/// Runs the same seed twice with the same bot, comparing state hashes at
/// checkpoints and at the end (AC-02). Returns null on success or a
/// human-readable mismatch description.
String? verifyReplay(
  Balance balance,
  int seed, {
  Bot Function(Balance)? botFactory,
  int checkpointEvery = 500,
}) {
  final a = _hashTrace(balance, seed, checkpointEvery, botFactory);
  final b = _hashTrace(balance, seed, checkpointEvery, botFactory);
  if (a.length != b.length) {
    return 'trace length mismatch: ${a.length} vs ${b.length}';
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return 'hash mismatch at checkpoint $i: ${a[i]} vs ${b[i]}';
    }
  }
  return null;
}

List<String> _hashTrace(
  Balance balance,
  int seed,
  int every,
  Bot Function(Balance)? botFactory,
) {
  final state = GameState.initial(balance, seed);
  final engine = Engine(balance);
  final bot = (botFactory ?? SteadyBot.new)(balance);
  final hashes = <String>[];
  while (state.alive) {
    engine.tick(state, bot.decide(state));
    if (state.week % every == 0) hashes.add(hashHex(state.stateHash()));
  }
  hashes.add(hashHex(state.stateHash()));
  return hashes;
}
