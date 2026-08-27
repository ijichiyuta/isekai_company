import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/game_controller.dart';
import 'package:isekai_app/game/providers.dart';
import 'package:isekai_app/game/tick_clock.dart';
import 'package:isekai_app/ui/event_dialog.dart';
import 'package:isekai_app/ui/invention_overlay.dart';
import 'package:isekai_app/ui/main_screen.dart';
import 'package:isekai_app/ui/onboarding.dart';
import 'package:isekai_app/ui/theme.dart';

import 'helpers.dart';

// Renders the real UI to PNGs (goldens) in-process. macOS-only so CI on Linux
// skips it. Run: flutter test test/golden_test.dart --update-goldens
Future<void> _loadHiragino() async {
  const path = '/System/Library/Fonts/ヒラギノ角ゴシック W4.ttc';
  final f = File(path);
  if (!f.existsSync()) return;
  final bytes = f.readAsBytesSync();
  final loader = FontLoader('Hiragino')
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

Widget _framed(Widget child) => ProviderScope(
  overrides: [
    balanceProvider.overrideWith((ref) => Future.value(loadTestBalance())),
    tickClockProvider.overrideWithValue(FakeTickClock()),
    saveStoreProvider.overrideWith((ref) async => null),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme().copyWith(
      textTheme: buildTheme().textTheme.apply(fontFamily: 'Hiragino'),
    ),
    home: Consumer(
      builder: (c, ref, _) {
        // The child's gameControllerProvider requireValue's balance + store +
        // restored + entitlements — wait for all before building.
        final b = ref.watch(balanceProvider);
        final r = ref.watch(restoredSaveProvider);
        final e = ref.watch(entitlementsProvider);
        if (b.isLoading || r.isLoading || e.isLoading) {
          return const SizedBox.shrink();
        }
        if (b.hasError) return Text('${b.error}');
        return child;
      },
    ),
  ),
);

void main() {
  testWidgets('golden: main screen', (tester) async {
    if (!Platform.isMacOS) return; // font + render is host-specific
    await _loadHiragino();
    tester.view.physicalSize = const Size(780, 1688); // iPhone-ish @2x
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_framed(const MainScreen()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MainScreen),
      matchesGoldenFile('goldens/main_screen.png'),
    );
  });

  testWidgets('golden: onboarding intro (転生カットイン)', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadHiragino();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme().copyWith(
          textTheme: buildTheme().textTheme.apply(
            fontFamily: 'Hiragino',
            bodyColor: const Color(0xFFFFFFFF),
            displayColor: const Color(0xFFFFFFFF),
          ),
        ),
        home: OnboardingFlow(onDone: () {}),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(OnboardingFlow),
      matchesGoldenFile('goldens/onboarding.png'),
    );
  });

  testWidgets('golden: event dialog (イベント選択)', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadHiragino();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final balance = loadTestBalanceWithEvents();
    final event = balance.events[20]; // 勇者パーティのスポンサー (2 choices)
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme().copyWith(
          textTheme: buildTheme().textTheme.apply(fontFamily: 'Hiragino'),
        ),
        home: Stack(
          children: [
            Container(color: const Color(0xFFF3E9D2)),
            EventDialog(event: event, onChoose: (_) {}),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(EventDialog),
      matchesGoldenFile('goldens/event.png'),
    );
  });

  testWidgets('golden: invention overlay (プリン発明演出)', (tester) async {
    if (!Platform.isMacOS) return;
    await _loadHiragino();
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme().copyWith(
          textTheme: buildTheme().textTheme.apply(fontFamily: 'Hiragino'),
        ),
        home: Stack(
          children: [
            Container(color: const Color(0xFFF3E9D2)),
            InventionOverlay(
              event: const InventionEvent(0, 'プリン', 300, 30),
              onDismiss: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700)); // settle animation

    await expectLater(
      find.byType(InventionOverlay),
      matchesGoldenFile('goldens/invention.png'),
    );
  });
}
