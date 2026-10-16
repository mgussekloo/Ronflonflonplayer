import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/episode.dart';
import '../models/listening_state.dart';

abstract interface class ProgressStore {
  ListeningState read();
  Future<void> write(ListeningState state);
}

class PreferencesProgressStore implements ProgressStore {
  PreferencesProgressStore(this.preferences);
  final SharedPreferences preferences;
  static const key = 'ronflonflon.progress.v1';

  @override
  ListeningState read() {
    final value = preferences.getString(key);
    if (value == null) return ListeningState();
    // Corrupt data is reported rather than silently overwritten.
    return ListeningState.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  @override
  Future<void> write(ListeningState state) async {
    if (!await preferences.setString(key, jsonEncode(state.toJson()))) {
      throw StateError('The browser or device could not save your progress.');
    }
  }
}

class LibraryResult {
  const LibraryResult(this.episodes, {this.offline = false});
  final List<Episode> episodes;
  final bool offline;
}

class LibraryRepository {
  LibraryRepository(this.preferences, {http.Client? client})
    : _client = client ?? http.Client();
  final SharedPreferences preferences;
  final http.Client _client;
  static const catalogKey = 'ronflonflon.catalog.v1';

  Future<LibraryResult> load() async {
    try {
      final response = await _client
          .get(Uri.https('archive.org', '/metadata/$archiveIdentifier'))
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200) {
        throw StateError('Archive.org returned ${response.statusCode}.');
      }
      final metadata = jsonDecode(response.body) as Map<String, dynamic>;
      final episodes = Episode.fromMetadata(metadata);
      if (episodes.isEmpty) {
        throw StateError('No episodes were found in the archive.');
      }
      // Keep just the audio metadata, not the archive's artwork/derivative records.
      final compact = jsonEncode({
        'files': (metadata['files'] as List)
            .where(
              (file) => (file['name'] as String? ?? '').toLowerCase().endsWith(
                '.mp3',
              ),
            )
            .toList(),
      });
      try {
        await preferences.setString(catalogKey, compact);
      } catch (_) {
        /* Playback still works without a cached catalog. */
      }
      return LibraryResult(episodes);
    } catch (_) {
      final cached = preferences.getString(catalogKey);
      if (cached != null) {
        final episodes = Episode.fromMetadata(
          jsonDecode(cached) as Map<String, dynamic>,
        );
        if (episodes.isNotEmpty) return LibraryResult(episodes, offline: true);
      }
      rethrow;
    }
  }

  void close() => _client.close();
}
