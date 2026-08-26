import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/providers.dart';
import 'main_screen.dart';
import 'theme.dart';

class IsekaiApp extends StatelessWidget {
  const IsekaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '異世界カンパニー',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Bootstrap(),
    );
  }
}

/// Waits for the bundled balance to load, then shows the game.
class _Bootstrap extends ConsumerWidget {
  const _Bootstrap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceProvider);
    return balance.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('balance load failed:\n$e',
              textAlign: TextAlign.center),
        )),
      ),
      data: (_) => const MainScreen(),
    );
  }
}
