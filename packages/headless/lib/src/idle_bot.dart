import 'base_bot.dart';
import 'package:isekai_core/isekai_core.dart';

/// 放置型 (requirements §18.1): minimal operation, "leave it to automation".
/// It still bootstraps (a totally passive player in a fresh life just goes
/// bankrupt, which measures nothing), but reinvests reluctantly: rarely hires,
/// keeps a cash reserve, holds little forward stock. It is the FLOOR strategy —
/// it should survive (下限保証) yet grow slowly, so 攻め型 beats it on weekly
/// profit rate by 10–20% (AC-10) once the richer economy exists.
class IdleBot extends BaseBot {
  IdleBot(Balance balance) : super(balance);

  @override
  String get name => 'idle';

  @override
  int get developMinFunds => 20; // can still bootstrap discovery

  @override
  int get hireWageBuffer => 40; // hire only with a very fat buffer

  @override
  int get hireCeiling => 4; // never scales the workforce far

  @override
  int get stockHeadroomWeeks => 1; // minimal forward stock

  @override
  int get materialCashReserve => 40; // modest hoard, still leaves room to produce
}
