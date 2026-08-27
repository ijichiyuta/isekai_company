import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_app/ui/pixel/pixel_art.dart';
import 'package:isekai_app/ui/pixel/sprites.dart';

// Guards the sprite invariant (every row == width) so an authoring typo fails
// fast, and renders a contact sheet so the art can be eyeballed / iterated.
// Run: flutter test test/pixel_sprites_test.dart --update-goldens

void main() {
  test('every sprite is rectangular (rows all equal width)', () {
    final all = <String, PixelSprite>{
      ...kIconSprites,
      'shop': shop,
      'hero': hero,
      'customer': customer,
      'crate': crate,
      'plant': plant,
      'window': window,
      'goddess': goddess,
      'shopHd': shopHd,
      'heroHd': heroHd,
      'villagerHd': villagerHd,
      'ladyHd': ladyHd,
      'elderHd': elderHd,
      'adventurerHd': adventurerHd,
      'barrel': barrel,
      'catFood': catFood,
      'catTool': catTool,
      'catCloth': catCloth,
      'catMed': catMed,
      'catLux': catLux,
      'sack': sack,
    };
    all.forEach((name, s) {
      final widths = s.rows.map((r) => r.length).toSet();
      expect(widths.length, 1, reason: '$name has ragged rows: widths=$widths');
    });
  });

  test('sprite chars are all in the palette (or transparent)', () {
    final all = <String, PixelSprite>{
      ...kIconSprites,
      'shop': shop,
      'hero': hero,
      'customer': customer,
      'crate': crate,
      'plant': plant,
      'window': window,
      'goddess': goddess,
      'shopHd': shopHd,
      'heroHd': heroHd,
      'villagerHd': villagerHd,
      'ladyHd': ladyHd,
      'elderHd': elderHd,
      'adventurerHd': adventurerHd,
      'barrel': barrel,
      'catFood': catFood,
      'catTool': catTool,
      'catCloth': catCloth,
      'catMed': catMed,
      'catLux': catLux,
      'sack': sack,
    };
    all.forEach((name, s) {
      for (final row in s.rows) {
        for (final ch in row.split('')) {
          if (ch == '.' || ch == ' ') continue;
          expect(
            s.palette.containsKey(ch),
            isTrue,
            reason: '$name uses unknown palette key "$ch"',
          );
        }
      }
    });
  });

  testWidgets('contact sheet (visual review)', (tester) async {
    if (!Platform.isMacOS) return;
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget cell(String label, PixelSprite s, double px) => Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(6),
      color: const Color(0xFFF3E9D2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PixelView(s, pixelSize: px),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFDCC9A0),
          body: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (final e in kIconSprites.entries) cell(e.key, e.value, 5),
                cell('hero', hero, 5),
                cell('goddess', goddess, 5),
                cell('customer', customer, 5),
                cell('crate', crate, 5),
                cell('plant', plant, 5),
                cell('window', window, 5),
                cell('shop', shop, 5),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/pixel_contact_sheet.png'),
    );
  });

  testWidgets('shop HD preview (large)', (tester) async {
    if (!Platform.isMacOS) return;
    tester.view.physicalSize = const Size(1320, 980);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFEAD8AC),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PixelView(shopHd, pixelSize: 5),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final s in [
                      heroHd,
                      villagerHd,
                      ladyHd,
                      elderHd,
                      adventurerHd,
                    ]) ...[
                      PixelView(s, pixelSize: 4),
                      const SizedBox(width: 20),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/shop_hd_preview.png'),
    );
  });

  testWidgets('hd icons + props', (tester) async {
    if (!Platform.isMacOS) return;
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final items = <(String, PixelSprite)>[
      ('funds', coin),
      ('fame', star),
      ('settings', gear),
      ('develop', beaker),
      ('produce', factoryIcon),
      ('sell', storefront),
      ('order', cart),
      ('trend', flame),
      ('invent', sparkle),
      ('food', catFood),
      ('tool', catTool),
      ('cloth', catCloth),
      ('medicine', catMed),
      ('luxury', catLux),
      ('material', sack),
      ('crate', crate),
      ('barrel', barrel),
      ('window', window),
      ('plant', plant),
      ('goddess', goddess),
    ];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFEAD8AC),
          body: Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 22,
              runSpacing: 18,
              children: [
                for (final (_, s) in items)
                  SizedBox(
                    width: 92,
                    child: SizedBox(
                      height: 88,
                      child: Center(child: PixelView(s, height: 82)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/hd_icons_preview.png'),
    );
  });

  testWidgets('face close-up', (tester) async {
    if (!Platform.isMacOS) return;
    tester.view.physicalSize = const Size(1000, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFEAD8AC),
          body: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PixelView(heroHd, pixelSize: 8),
                const SizedBox(width: 20),
                PixelView(adventurerHd, pixelSize: 8),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/face_preview.png'),
    );
  });
}
