import 'base_bot.dart';
import 'package:isekai_core/isekai_core.dart';

/// 放置型 (requirements §18.1): "leave it to automation" (魂の記憶 #15自動値付け/
/// #16自動発注). It auto-manages — hires, reinvests, restocks — but is
/// trend-BLIND: it produces by margin and never front-loads the trending
/// category. So 攻め型 (manual, trend-aware) beats it on the weekly profit rate
/// by the manual edge (§6/§7 / AC-10). Still conservative (fat cushions) so it
/// remains the survival floor (下限保証).
class IdleBot extends BaseBot {
  IdleBot(Balance balance) : super(balance);

  @override
  String get name => 'idle';

  @override
  int get developMinFunds => 20; // can still bootstrap discovery

  @override
  int get hireWageBuffer => 12; // auto-hires, but with a comfortable buffer

  @override
  int get stockHeadroomWeeks => 1; // minimal forward stock

  @override
  int get materialCashReserve => 40; // modest hoard, still leaves room to produce

  @override
  bool get reinvest => true; // auto-reinvests (auto-managed 放置)

  // trendAware stays false — the whole point of AC-10: no manual trend capture.
}
