import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:isekai_core/isekai_core.dart';

/// Loads the bundled balance JSON (app is the IO boundary; core never touches
/// dart:io). MVP ships balance in-app (requirements §16.2 — remote override is
/// v1.0+).
Future<Balance> loadBundledBalance() async {
  Future<Map<String, dynamic>> read(String name) async {
    final text = await rootBundle.loadString('assets/balance/$name');
    return jsonDecode(text) as Map<String, dynamic>;
  }

  return Balance.fromJsonMaps(
    economyJson: await read('economy.json'),
    materialsJson: await read('materials.json'),
    recipesJson: await read('recipes.json'),
    ranksJson: await read('ranks.json'),
    eventsJson: await read('events.json'), // the app plays with events (§3.7)
    unlocksJson: await read('unlocks.json'), // 魂の記憶 tree (§8.4)
  );
}
