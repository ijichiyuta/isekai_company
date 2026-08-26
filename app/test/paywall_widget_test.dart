import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/game/iap_stub.dart';
import 'package:isekai_app/game/providers.dart';
import 'package:isekai_app/game/tick_clock.dart';
import 'package:isekai_app/ui/settings_screen.dart';
import 'package:isekai_app/ui/soul_memory_screen.dart';

import 'helpers.dart';

class _FakeIap implements IapClient {
  final bool ok;
  _FakeIap(this.ok);
  @override
  bool get available => true;
  @override
  Future<bool> purchaseFull() async => ok;
  @override
  Future<bool> restore() async => ok;
}

Future<void> _pump(WidgetTester t, Widget screen, {IapClient? iap}) async {
  await t.pumpWidget(ProviderScope(
    overrides: [
      balanceProvider.overrideWith((r) => Future.value(loadTestBalanceFull())),
      tickClockProvider.overrideWithValue(FakeTickClock()),
      saveStoreProvider.overrideWith((r) async => null),
      if (iap != null) iapClientProvider.overrideWithValue(iap),
    ],
    child: MaterialApp(
      home: Consumer(builder: (c, ref, _) {
        final b = ref.watch(balanceProvider);
        final r = ref.watch(restoredSaveProvider);
        final e = ref.watch(entitlementsProvider);
        if (b.isLoading || r.isLoading || e.isLoading) {
          return const SizedBox.shrink();
        }
        return screen;
      }),
    ),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('tree lists unlocks; full-tier nodes are gated behind 完全版',
      (t) async {
    await _pump(t, const SoulMemoryScreen());
    expect(find.text('魂の記憶'), findsOneWidget); // app bar
    expect(find.text('貯えの記憶 I'), findsOneWidget); // top free node (§8.4 #1a)
    // Full-tier nodes render a 完全版 lock affordance.
    expect(find.widgetWithText(TextButton, '完全版'), findsWidgets);
  });

  testWidgets('paywall purchase (fake IAP) flips to 完全版', (t) async {
    await _pump(t, const SoulMemoryScreen(), iap: _FakeIap(true));
    await t.tap(find.byIcon(Icons.lock_open)); // header CTA (unique icon)
    await t.pumpAndSettle();
    expect(find.text('完全版を購入'), findsOneWidget);
    await t.tap(find.text('完全版を購入'));
    await t.pumpAndSettle();
    expect(find.text('✔ 完全版 購入済み'), findsOneWidget); // header now owned
  });

  testWidgets('settings exposes a 復元 entry (App Store 3.1.1)', (t) async {
    await _pump(t, const SettingsScreen(), iap: _FakeIap(true));
    expect(find.text('購入を復元'), findsOneWidget);
    await t.tap(find.text('購入を復元'));
    await t.pumpAndSettle();
    expect(find.text('完全版 購入済み'), findsOneWidget); // restore succeeded
  });
}
