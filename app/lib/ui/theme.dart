import 'package:flutter/material.dart';

/// A warm, parchment-and-ink palette befitting a merchant in another world.
/// Kept small and centralized (the Art Bible will formalize this in M1).
ThemeData buildTheme() {
  const seed = Color(0xFF8B5E34); // aged leather brown
  final scheme =
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      ).copyWith(
        surface: const Color(0xFFF3E9D2), // parchment
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF3E9D2),
    fontFamily: null,
    appBarTheme: const AppBarTheme(centerTitle: true),
  );
}

const kGold = Color(0xFFC8991F);
const kFame = Color(0xFF6A4FB6);
