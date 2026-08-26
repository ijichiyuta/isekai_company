import 'base_bot.dart';
import 'package:isekai_core/isekai_core.dart';

/// 攻め型 (requirements §18.1): aggressive expansion, thin cash buffer. Hires
/// hard and keeps no reserve, so it grows faster (upside) but risks bankruptcy
/// more than steady. Stands in for the "manual optimizer" in AC-10 (should beat
/// 放置型 on weekly profit rate) and stress-tests AC-07's high end.
class AttackBot extends BaseBot {
  AttackBot(Balance balance) : super(balance);

  @override
  String get name => 'attack';

  @override
  int get developMinFunds => 12; // experiment even when nearly broke

  @override
  int get hireWageBuffer => 2; // hire on a razor-thin buffer

  @override
  int get stockHeadroomWeeks => 3; // build more forward stock

  @override
  int get materialCashReserve => 0; // spend everything on growth

  @override
  bool get reinvest => true; // aggressive: upgrades on a thin cushion

  @override
  int get reinvestFundsMult => 2; // buys upgrades sooner than steady

  @override
  bool get trendAware => true; // manual optimizer: captures trends (§7 / AC-10)
}
