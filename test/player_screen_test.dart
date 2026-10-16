import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ronflonflon_player/main.dart';
import 'package:ronflonflon_player/models/episode.dart';
import 'package:ronflonflon_player/player/player_controller.dart';
import 'package:ronflonflon_player/services/library_repository.dart';
import 'package:ronflonflon_player/ui/player_screen.dart';
import 'player_controller_test.dart' show FakeCache, FakeEngine, MemoryStore;

void main() {
  test('Episode dates use Dutch month abbreviations and fallback', () {
    const months = [
      'jan',
      'feb',
      'mrt',
      'apr',
      'mei',
      'jun',
      'jul',
      'aug',
      'sep',
      'okt',
      'nov',
      'dec',
    ];
    for (var month = 1; month <= 12; month++) {
      expect(
        episodeDate(
          Episode(
            fileName: 'test.mp3',
            number: 1,
            date: DateTime(1985, month, 10),
          ),
        ),
        '10 ${months[month - 1]} 1985',
      );
    }
    expect(
      episodeDate(const Episode(fileName: 'test.mp3', number: 1)),
      'Datum onbekend',
    );
  });

  testWidgets('Player uses Dutch copy, controls and Material localization', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = PlayerController(
      engine: FakeEngine(),
      cache: FakeCache(),
      store: MemoryStore(),
    );
    final library = LibraryRepository(
      preferences,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'files': [
              {'name': 'Ronflonflon 001-1984-10-10.mp3', 'length': '3000'},
            ],
          }),
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      RonflonflonApp(controller: controller, library: library),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(PlayerScreen));
    expect(Localizations.localeOf(context), const Locale('nl'));
    expect(MaterialLocalizations.of(context).copyButtonLabel, 'Kopiëren');
    expect(
      find.text('De radio, de radio, wat is er op de radio?'),
      findsOneWidget,
    );
    expect(
      find.text('Alle uitzendingen van gisteren! Maar dan vandaag.'),
      findsOneWidget,
    );
    expect(find.text('1 beschikbaar · 0 beluisterd'), findsOneWidget);
    expect(find.text('Uitzending 001'), findsOneWidget);
    expect(find.text('10 okt 1984 · 50:00'), findsOneWidget);
    expect(find.text('Begin met luisteren'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'onbekend');
    await tester.pumpAndSettle();
    expect(find.text('Geen uitzendingen gevonden.'), findsOneWidget);
    await tester.tap(find.byTooltip('Over deze speler'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Deze onafhankelijke speler'), findsOneWidget);
    await tester.tap(find.text('Begrepen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
