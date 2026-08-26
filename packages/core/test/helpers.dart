import 'dart:convert';
import 'dart:io';

import 'package:isekai_core/isekai_core.dart';

/// Builds the real bundled balance from disk (test files may use dart:io; the
/// core library itself may not). cwd is packages/core under `dart test`.
Balance testBalance() {
  Map<String, dynamic> read(String name) => jsonDecode(
      File('../../assets/balance/$name').readAsStringSync())
      as Map<String, dynamic>;
  return Balance.fromJsonMaps(
    economyJson: read('economy.json'),
    materialsJson: read('materials.json'),
    recipesJson: read('recipes.json'),
    ranksJson: read('ranks.json'),
  );
}
