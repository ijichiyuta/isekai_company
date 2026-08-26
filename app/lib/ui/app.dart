import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/providers.dart';
import 'game_root.dart';
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

/// Waits for the bundled balance AND the restored save to load, then shows the
/// game. Watching [restoredSaveProvider] transitively awaits balance + store +
/// load, so [gameControllerProvider]'s requireValue calls never race. Also
/// persists the game when the app is backgrounded (§17.1 crash-safety).
class _Bootstrap extends ConsumerStatefulWidget {
  const _Bootstrap();
  @override
  ConsumerState<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends ConsumerState<_Bootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      // Save on background so a swipe-kill can't lose the session.
      final boot = ref.read(restoredSaveProvider);
      if (boot.hasValue) ref.read(gameControllerProvider).persist();
    }
  }

  @override
  Widget build(BuildContext context) {
    // GameRoot reads gameControllerProvider, which requireValue's all three of
    // balance / store / restored. Gate on balance AND the restored save so none
    // is still loading when GameRoot builds (the store may be overridden in a
    // way that doesn't chain through balance).
    final balance = ref.watch(balanceProvider);
    final restored = ref.watch(restoredSaveProvider);
    final err = balance.hasError
        ? balance.error
        : (restored.hasError ? restored.error : null);
    if (err != null) {
      return Scaffold(
        body: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('load failed:\n$err', textAlign: TextAlign.center),
        )),
      );
    }
    if (balance.isLoading || restored.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return const GameRoot();
  }
}
