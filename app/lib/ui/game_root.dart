import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/providers.dart';
import 'develop_screen.dart';
import 'main_screen.dart';
import 'onboarding.dart';

/// Test/debug hook to force-skip onboarding (set false). Real persistence lives
/// in meta: [GameController.tutorialDone] (§C-6) drives the 2周目 / relaunch
/// auto-skip. In production this stays true and tutorialDone gates the flow.
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
    // Tutorial complete once they've been through the guided develop — persist
    // it so 2周目 / relaunch skips onboarding (§C-6).
    if (!mounted) return;
    ref.read(gameControllerProvider).completeTutorial();
  }

  @override
  Widget build(BuildContext context) {
    // Real persistence: skip onboarding when the saved meta says it's done.
    final done = ref.watch(
        gameControllerProvider.select((g) => g.tutorialDone));
    final hook = ref.watch(tutorialActiveProvider); // test/debug force-skip
    if (hook && !done && !_introDone) {
      return OnboardingFlow(onDone: _finishIntro);
    }
    return const MainScreen();
  }
}
