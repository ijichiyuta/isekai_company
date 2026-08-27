import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/providers.dart';
import 'package:isekai_app/game/tick_clock.dart';
import 'package:isekai_app/ui/app.dart';
import 'package:isekai_app/ui/game_root.dart';

import 'helpers.dart';

Widget _app({bool tutorial = false}) {
  final balance = loadTestBalance();
  // Pump the real IsekaiApp so its bootstrap gate (loading → data) runs; this
  // avoids the requireValue race a bare MainScreen would hit before load.
  return ProviderScope(
    overrides: [
      balanceProvider.overrideWith((ref) => Future.value(balance)),
      tickClockProvider.overrideWithValue(FakeTickClock()),
      // No filesystem in widget tests — run the game in-memory (no persistence).
      saveStoreProvider.overrideWith((ref) async => null),
      tutorialActiveProvider.overrideWith((ref) => tutorial),
    ],
    child: const IsekaiApp(),
  );
}

void main() {
  testWidgets('main screen renders HUD and the loop screens are reachable', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('行商人'), findsOneWidget); // starting rank
    expect(find.text('×1'), findsOneWidget); // speed control
    expect(find.text('開発'), findsOneWidget);
    expect(find.text('発注'), findsOneWidget);

    // HUD stat icons carry semantic labels (a11y): screen readers announce
    // "資金"/"名声" rather than an unlabeled image.
    bool hasSemanticLabel(String label) => find
        .byWidgetPredicate((w) => w is Semantics && w.properties.label == label)
        .evaluate()
        .isNotEmpty;
    expect(hasSemanticLabel('資金'), isTrue);
    expect(hasSemanticLabel('名声'), isTrue);

    await tester.tap(find.text('開発'));
    await tester.pumpAndSettle();
    expect(find.text('PB開発'), findsOneWidget);
  });

  testWidgets('developing pudding plays the invention overlay', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('開発'));
    await tester.pumpAndSettle();

    // Each material appears in both slots; pick wheat in slot 1 (first) and
    // egg in slot 2 (last). cooling is method 0 (default).
    await tester.tap(find.text('小麦 (2G)').first);
    await tester.pump();
    await tester.tap(find.text('卵 (3G)').last);
    await tester.pump();
    await tester.tap(find.textContaining('開発する'));
    await tester.pumpAndSettle();

    // Develop screen auto-pops on invention → overlay is shown on MainScreen.
    expect(find.text('「プリン」を発明！'), findsOneWidget);

    // Dismissing the overlay clears it.
    await tester.tap(find.text('タップして続ける'));
    await tester.pumpAndSettle();
    expect(find.text('「プリン」を発明！'), findsNothing);
  });

  testWidgets('onboarding: intro → guided develop → guaranteed invention', (
    tester,
  ) async {
    await tester.pumpWidget(_app(tutorial: true));
    await tester.pumpAndSettle();

    // Intro plays first.
    expect(find.text('スキップ'), findsOneWidget);
    // Walk to the last intro card, then start.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    // The guided develop screen opens with pudding pre-selected + a hint.
    expect(find.text('PB開発'), findsOneWidget);
    expect(find.textContaining('小麦 × 卵'), findsOneWidget);

    // Just press the develop button (unique "素材費" label) — materials are
    // pre-selected.
    await tester.tap(find.textContaining('素材費'));
    await tester.pumpAndSettle();

    // Auto-returns to main and plays the invention overlay.
    expect(find.text('「プリン」を発明！'), findsOneWidget);
  });
}
