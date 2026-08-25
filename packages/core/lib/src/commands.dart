/// Player/system inputs. Everything that mutates the simulation flows through
/// commands — including external grants (offline rewards, IAP perks), per
/// requirements §2.2 rule 4. Commands serialize for the journal (§17.1).
library;

sealed class Command {
  Map<String, dynamic> toJson();

  static Command fromJson(Map<String, dynamic> m) {
    switch (m['t'] as String) {
      case 'order':
        return OrderMaterial(m['id'] as int, m['qty'] as int);
      case 'develop':
        return Develop(m['a'] as int, m['b'] as int, m['method'] as int);
      case 'produce':
        return Produce(m['id'] as int, m['qty'] as int);
      case 'hire':
        return Hire();
      case 'grant':
        return Grant(m['amount'] as int, m['reason'] as String);
      default:
        throw ArgumentError('unknown command type: ${m['t']}');
    }
  }
}

class OrderMaterial extends Command {
  final int materialId;
  final int qty;
  OrderMaterial(this.materialId, this.qty);
  @override
  Map<String, dynamic> toJson() => {'t': 'order', 'id': materialId, 'qty': qty};
}

class Develop extends Command {
  final int matA;
  final int matB;
  final int method;
  Develop(this.matA, this.matB, this.method);
  @override
  Map<String, dynamic> toJson() =>
      {'t': 'develop', 'a': matA, 'b': matB, 'method': method};
}

class Produce extends Command {
  final int recipeId;
  final int qty;
  Produce(this.recipeId, this.qty);
  @override
  Map<String, dynamic> toJson() => {'t': 'produce', 'id': recipeId, 'qty': qty};
}

class Hire extends Command {
  @override
  Map<String, dynamic> toJson() => {'t': 'hire'};
}

class Grant extends Command {
  final int amount;
  final String reason;
  Grant(this.amount, this.reason);
  @override
  Map<String, dynamic> toJson() =>
      {'t': 'grant', 'amount': amount, 'reason': reason};
}
