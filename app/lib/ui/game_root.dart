import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/providers.dart';
import 'develop_screen.dart';
import 'main_screen.dart';
import 'onboarding.dart';

/// Whether the first-run tutorial should play. In-memory for M1 (resets each
/// launch); persisting it + 2周目 auto-skip lands when meta/save is wired (M3).
final tutorialActiveProvider = StateProvider<bool>((ref) => true);

/// Sequences the first-run experience: onboarding intro → guided pudding
/// develop → free play. After the tutorial (or a skip), it's just [MainScreen].
class GameRoot extends ConsumerStatefulWidget {
  const GameRoot({super.key});
  @override
  ConsumerState<GameRoot> createState() => _GameRootState();
}

class _GameRootState extends ConsumerState<GameRoot> {
  bool _introDone = false;
  bool _guided = false;

  void _finishIntro() {
    setState(() => _introDone = true);
    // After the intro, open the guided develop screen once so the player is
    // guaranteed to hit the first invention (§13 first_invention).
    WidgetsBinding.instance.addPostFrameCallback((_) => _openGuidedDevelop());
  }

  Future<void> _openGuidedDevelop() async {
    if (_guided || !mounted) return;
    _guided = true;
    final game = ref.read(gameControllerProvider);
    game.pauseForScreen();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DevelopScreen(tutorial: true)),
    );
    // Tutorial complete once they've been through the guided develop.
    ref.read(tutorialActiveProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final tutorial = ref.watch(tutorialActiveProvider);
    if (tutorial && !_introDone) {
      return OnboardingFlow(onDone: _finishIntro);
    }
    return const MainScreen();
  }
}
