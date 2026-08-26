import 'base_bot.dart';
import 'package:isekai_core/isekai_core.dart';

/// 堅実型 (requirements §18.1): steady prices, steady investment. Balanced
/// defaults — the reference strategy for AC-07 (bankruptcy) and AC-08 (rank
/// reach). All behaviour comes from [BaseBot]'s defaults.
class SteadyBot extends BaseBot {
  SteadyBot(Balance balance) : super(balance);
  @override
  String get name => 'steady';
}
