import 'package:isekai_core/isekai_core.dart';
import 'package:isekai_headless/isekai_headless.dart';

/// Debug: weekly state trace for a single life. Usage:
///   dart run bin/trace.dart [seed]
void main(List<String> args) {
  final seed = args.isNotEmpty ? int.parse(args[0]) : 1;
  final balance = loadBalanceFromDir('../../assets/balance');
  final s = GameState.initial(balance, seed);
  final engine = Engine(balance);
  final bot = SteadyBot(balance);

  print('week funds fame emp disc inv prodStock matStock');
  while (s.alive) {
    final cmds = bot.decide(s);
    engine.tick(s, cmds);
    final everyN = s.week <= 120 ? 4 : 100;
    if (s.week % everyN == 0 || !s.alive) {
      final prod = s.productStock.fold<int>(0, (a, b) => a + b);
      final mat = s.materialStock.fold<int>(0, (a, b) => a + b);
      print('${s.week.toString().padLeft(4)} '
          '${s.funds.toString().padLeft(8)} '
          '${s.fame.toString().padLeft(6)} '
          '${s.employees.toString().padLeft(3)} '
          '${s.discoveries.toString().padLeft(3)} '
          '${s.inventions.toString().padLeft(3)} '
          '${prod.toString().padLeft(5)} '
          '${mat.toString().padLeft(5)}');
    }
  }
  print('end: week=${s.week} reason=${s.endReason} funds=${s.funds} '
      'rank=${s.rank} discoveries=${s.discoveries}');
}
