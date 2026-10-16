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
      expect(find.text('avec Jacques Plafond'), findsOneWidget);
      await tester.tap(find.byTooltip('About this player'));
      expect(opened, isTrue);
    });
  }
}
