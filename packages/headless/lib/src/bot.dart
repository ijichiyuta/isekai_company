import 'package:isekai_core/isekai_core.dart';

/// An autoplay strategy (requirements §18.1). Bots decide purely from the
/// visible [GameState] and emit commands through the same public API a human
/// uses. Keeping them STATELESS (no hidden fields that evolve tick-to-tick)
/// guarantees a save/load mid-life resumes bit-identically.
abstract interface class Bot {
  String get name;
  List<Command> decide(GameState s);
}

/// Registry of the four bots (§18.1) by short name, for the CLI runner.
typedef BotFactory = Bot Function(Balance balance);
