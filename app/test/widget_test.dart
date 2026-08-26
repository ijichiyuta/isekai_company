import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/providers.dart';
import 'package:isekai_app/game/tick_clock.dart';
import 'package:isekai_app/ui/app.dart';

import 'helpers.dart';

Widget _app() {
  final balance = loadTestBalance();
  // Pump the real IsekaiApp so its bootstrap gate (loading → data) runs; this
  // avoids the requireValue race a bare MainScreen would hit before load.
  return ProviderScope(
    overrides: [
      balanceProvider.overrideWith((ref) => Future.value(balance)),
      tickClockProvider.overrideWithValue(FakeTickClock()),
    ],
    child: const IsekaiApp(),
  );
}

void main() {
  testWidgets('main screen renders HUD and the loop screens are reachable',
      (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('行商人'), findsOneWidget); // starting rank
    expect(find.text('×1'), findsOneWidget); // speed control
    expect(find.text('開発'), findsOneWidget);
    expect(find.text('発注'), findsOneWidget);

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
}
