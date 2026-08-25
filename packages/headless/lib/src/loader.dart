import 'dart:convert';
import 'dart:io';

import 'package:isekai_core/isekai_core.dart';

/// Reads assets/balance/*.json and builds a validated [Balance].
/// File IO lives here on purpose — core is not allowed to touch dart:io.
Balance loadBalanceFromDir(String dir) {
  Map<String, dynamic> read(String name) =>
      jsonDecode(File('$dir/$name').readAsStringSync())
          as Map<String, dynamic>;
  return Balance.fromJsonMaps(
    economyJson: read('economy.json'),
    materialsJson: read('materials.json'),
    recipesJson: read('recipes.json'),
    ranksJson: read('ranks.json'),
  );
}
