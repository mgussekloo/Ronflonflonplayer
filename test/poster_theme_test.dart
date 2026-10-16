import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronflonflon_player/ui/poster_theme.dart';

void main() {
  for (final width in [320.0, 390.0, 1100.0]) {
    testWidgets('Poster header fits a $width-wide screen', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: PosterTheme.data,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: PosterHeader(onAbout: () => opened = true),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('met Jacques Plafond'), findsOneWidget);
      expect(
        find.text('De radio, de radio, wat is er op de radio?'),
        findsOneWidget,
      );
      expect(
        find.text('Alle uitzendingen van gisteren! Maar dan vandaag.'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Over deze speler'));
      expect(opened, isTrue);
    });
  }
}
