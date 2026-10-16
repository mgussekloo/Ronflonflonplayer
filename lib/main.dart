import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'player/audio_engine.dart';
import 'player/player_controller.dart';
import 'services/audio_cache.dart';
import 'services/library_repository.dart';
import 'ui/player_screen.dart';
import 'ui/poster_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final preferences = await SharedPreferences.getInstance();
    final controller = PlayerController(
      engine: JustAudioEngine(),
      cache: createAudioCache(),
      store: PreferencesProgressStore(preferences),
    );
    runApp(
      RonflonflonApp(
        controller: controller,
        library: LibraryRepository(preferences),
      ),
    );
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Could not open local storage. Allow site storage and reload the page.\n$error',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RonflonflonApp extends StatelessWidget {
  const RonflonflonApp({
    super.key,
    required this.controller,
    required this.library,
  });
  final PlayerController controller;
  final LibraryRepository library;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ronflonflon player',
    debugShowCheckedModeBanner: false,
    theme: PosterTheme.data,
    home: PlayerScreen(controller: controller, library: library),
  );
}
