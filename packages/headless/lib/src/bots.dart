import 'attack_bot.dart';
import 'bot.dart';
import 'collection_bot.dart';
import 'idle_bot.dart';
import 'steady_bot.dart';

/// The four-bot suite (requirements §18.1), keyed by CLI short name.
final Map<String, BotFactory> botRegistry = <String, BotFactory>{
  'steady': (b) => SteadyBot(b),
  'attack': (b) => AttackBot(b),
  'idle': (b) => IdleBot(b),
  'collection': (b) => CollectionBot(b),
};

BotFactory botFactoryByName(String name) {
  final f = botRegistry[name];
  if (f == null) {
    throw ArgumentError.value(
        name, 'bot', 'unknown bot; choose from ${botRegistry.keys.join(', ')}');
  }
  return f;
}
