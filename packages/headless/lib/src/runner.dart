import 'package:isekai_core/isekai_core.dart';

import 'steady_bot.dart';

class LifeStats {
  final int seed;
  final int weeks;
  final int funds;
  final int fame;
  final int rank;
  final int discoveries;
  final int inventions;
  final int rankUps;
  final int rewardEvents;
  final String endReason;
  final String finalHash;

  LifeStats({
    required this.seed,
    required this.weeks,
    required this.funds,
    required this.fame,
    required this.rank,
    required this.discoveries,
    required this.inventions,
    required this.rankUps,
    required this.rewardEvents,
    required this.endReason,
    required this.finalHash,
  });

  String toCsvRow() =>
      '$seed,$weeks,$funds,$fame,$rank,$discoveries,$inventions,$rankUps,'
      '$rewardEvents,$endReason,$finalHash';

  static const csvHeader = 'seed,weeks,funds,fame,rank,discoveries,inventions,'
      'rank_ups,reward_events,end_reason,final_hash';
}

LifeStats runLife(Balance balance, int seed, {int allowedBandMax = 1}) {
  final state =
      GameState.initial(balance, seed, allowedBandMax: allowedBandMax);
  final engine = Engine(balance);
  final bot = SteadyBot(balance);
  while (state.alive) {
    engine.tick(state, bot.decide(state));
  }
  return LifeStats(
    seed: seed,
    weeks: state.week,
    funds: state.funds,
    fame: state.fame,
    rank: state.rank,
    discoveries: state.discoveries,
    inventions: state.inventions,
    rankUps: state.rankUps,
    rewardEvents: state.rewardEvents,
    endReason: state.endReason,
    finalHash: hashHex(state.stateHash()),
  );
}

/// Runs the same seed twice, comparing state hashes at checkpoints and at the
/// end. Returns null on success or a human-readable mismatch description.
String? verifyReplay(Balance balance, int seed, {int checkpointEvery = 500}) {
  final hashesA = _hashTrace(balance, seed, checkpointEvery);
  final hashesB = _hashTrace(balance, seed, checkpointEvery);
  if (hashesA.length != hashesB.length) {
    return 'trace length mismatch: ${hashesA.length} vs ${hashesB.length}';
  }
  for (var i = 0; i < hashesA.length; i++) {
    if (hashesA[i] != hashesB[i]) {
      return 'hash mismatch at checkpoint $i: ${hashesA[i]} vs ${hashesB[i]}';
    }
  }
  return null;
}

List<String> _hashTrace(Balance balance, int seed, int every) {
  final state = GameState.initial(balance, seed);
  final engine = Engine(balance);
  final bot = SteadyBot(balance);
  final hashes = <String>[];
  while (state.alive) {
    engine.tick(state, bot.decide(state));
    if (state.week % every == 0) hashes.add(hashHex(state.stateHash()));
  }
  hashes.add(hashHex(state.stateHash()));
  return hashes;
}
