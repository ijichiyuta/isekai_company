import 'base_bot.dart';
import 'package:isekai_core/isekai_core.dart';

/// 放置型 (requirements §18.1): "leave it to automation" (魂の記憶 #15/#16). It
/// auto-manages — hires, reinvests, restocks — but conservatively (fat cushions,
/// low forward stock). This is the config that makes AC-10 pass: an auto-managed
/// 放置 player is competitive (closing the old +3658% reinvestment gap), and
/// 攻め型's aggressive management beats it by +10-20% (the "手動優位"). It also
/// stays the survival floor (下限保証). (The trend-timing edge §6/§7 is not yet
/// realized — see base_bot.trendAware / v0.9 audit.)
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
