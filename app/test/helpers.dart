import 'dart:convert';
import 'dart:io';

import 'package:isekai_core/isekai_core.dart';

/// Builds the real bundled balance by reading the JSON from disk (tests can use
/// dart:io; the app itself uses rootBundle). cwd is the package root under
/// `flutter test`.
Map<String, dynamic> _read(String name) =>
    jsonDecode(File('assets/balance/$name').readAsStringSync())
        as Map<String, dynamic>;

/// Events-less balance for stable widget/golden tests (no random event popups).
Balance loadTestBalance() => Balance.fromJsonMaps(
  economyJson: _read('economy.json'),
  materialsJson: _read('materials.json'),
  recipesJson: _read('recipes.json'),
  ranksJson: _read('ranks.json'),
);

/// Events-loaded balance, matching the real app, for event-flow tests.
Balance loadTestBalanceWithEvents() => Balance.fromJsonMaps(
  economyJson: _read('economy.json'),
  materialsJson: _read('materials.json'),
  recipesJson: _read('recipes.json'),
  ranksJson: _read('ranks.json'),
  eventsJson: _read('events.json'),
);

/// Full app config: events + 魂の記憶 unlocks (§8.4), for meta-progression tests.
Balance loadTestBalanceFull() => Balance.fromJsonMaps(
  economyJson: _read('economy.json'),
  materialsJson: _read('materials.json'),
  recipesJson: _read('recipes.json'),
  ranksJson: _read('ranks.json'),
  eventsJson: _read('events.json'),
  unlocksJson: _read('unlocks.json'),
);

/// The real app config INCLUDING the season/trend market (§6/§7, v0.9).
Balance loadTestBalanceMarket() => Balance.fromJsonMaps(
  economyJson: _read('economy.json'),
  materialsJson: _read('materials.json'),
  recipesJson: _read('recipes.json'),
  ranksJson: _read('ranks.json'),
  eventsJson: _read('events.json'),
  unlocksJson: _read('unlocks.json'),
  marketJson: _read('market.json'),
);
