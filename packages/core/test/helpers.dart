import 'dart:convert';
import 'dart:io';

import 'package:isekai_core/isekai_core.dart';

/// Builds the real bundled balance from disk (test files may use dart:io; the
/// core library itself may not). cwd is packages/core under `dart test`.
Map<String, dynamic> _read(String name) => jsonDecode(
    File('../../assets/balance/$name').readAsStringSync()) as Map<String, dynamic>;

Balance testBalance() => Balance.fromJsonMaps(
      economyJson: _read('economy.json'),
      materialsJson: _read('materials.json'),
      recipesJson: _read('recipes.json'),
      ranksJson: _read('ranks.json'),
    );

/// Real balance WITH events loaded (for event-system tests).
Balance testBalanceWithEvents() => Balance.fromJsonMaps(
      economyJson: _read('economy.json'),
      materialsJson: _read('materials.json'),
      recipesJson: _read('recipes.json'),
      ranksJson: _read('ranks.json'),
      eventsJson: _read('events.json'),
    );

/// Real balance with events + 魂の記憶 unlocks (the full app config).
Balance testBalanceFull() => Balance.fromJsonMaps(
      economyJson: _read('economy.json'),
      materialsJson: _read('materials.json'),
      recipesJson: _read('recipes.json'),
      ranksJson: _read('ranks.json'),
      eventsJson: _read('events.json'),
      unlocksJson: _read('unlocks.json'),
    );
