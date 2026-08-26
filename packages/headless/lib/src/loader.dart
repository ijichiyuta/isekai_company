import 'dart:convert';
import 'dart:io';

import 'package:isekai_core/isekai_core.dart';

/// Reads assets/balance/*.json and builds a validated [Balance].
/// File IO lives here on purpose — core is not allowed to touch dart:io.
///
/// [withEvents] is opt-in: the existing determinism/baseline runs stay
/// events-less (identical to the pre-events build), while the balance gate can
/// load events to measure reward pacing with events firing (audit A/C契約).
/// [withMarket] likewise loads the season/trend market (v0.9) — the gate measures
/// the real app config; the determinism baseline stays market-less (byte-identical).
Balance loadBalanceFromDir(String dir,
    {bool withEvents = false, bool withMarket = false}) {
  Map<String, dynamic> read(String name) =>
      jsonDecode(File('$dir/$name').readAsStringSync())
          as Map<String, dynamic>;
  Map<String, dynamic>? eventsJson;
  if (withEvents && File('$dir/events.json').existsSync()) {
    eventsJson = read('events.json');
  }
  Map<String, dynamic>? marketJson;
  if (withMarket && File('$dir/market.json').existsSync()) {
    marketJson = read('market.json');
  }
  return Balance.fromJsonMaps(
    economyJson: read('economy.json'),
    materialsJson: read('materials.json'),
    recipesJson: read('recipes.json'),
    ranksJson: read('ranks.json'),
    eventsJson: eventsJson,
    marketJson: marketJson,
  );
}
