import 'dart:convert';
import 'dart:io';

import 'package:isekai_core/isekai_core.dart';

/// Builds the real bundled balance by reading the JSON from disk (tests can use
/// dart:io; the app itself uses rootBundle). cwd is the package root under
/// `flutter test`.
Balance loadTestBalance() {
  Map<String, dynamic> read(String name) => jsonDecode(
      File('assets/balance/$name').readAsStringSync()) as Map<String, dynamic>;
  return Balance.fromJsonMaps(
    economyJson: read('economy.json'),
    materialsJson: read('materials.json'),
    recipesJson: read('recipes.json'),
    ranksJson: read('ranks.json'),
  );
}
