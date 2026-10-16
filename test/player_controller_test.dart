import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronflonflon_player/models/episode.dart';
import 'package:ronflonflon_player/models/listening_state.dart';
import 'package:ronflonflon_player/player/audio_engine.dart';
import 'package:ronflonflon_player/player/player_controller.dart';
import 'package:ronflonflon_player/services/audio_cache.dart';
import 'package:ronflonflon_player/services/library_repository.dart';

const first = Episode(
  fileName: 'Ronflonflon 001.mp3',
  number: 1,
  duration: Duration(minutes: 50),
);
const second = Episode(
  fileName: 'Ronflonflon 002.mp3',
  number: 2,
  duration: Duration(minutes: 50),
);

class MemoryStore implements ProgressStore {
  ListeningState value = ListeningState();
  bool fail = false;
  @override
  ListeningState read() => ListeningState.fromJson(value.toJson());
  @override
  Future<void> write(ListeningState state) async {
    if (fail) throw StateError('Storage unavailable');
    value = ListeningState.fromJson(state.toJson());
  }
}

class FakeCache implements AudioCache {
  final prepared = <String>[];
  final removed = <String>[];
  bool fail = false;
  bool failCleanup = false;
  Completer<void>? pending;
  @override
  Future<Uri> prepare(
    Episode episode,
    void Function(double?) onProgress,
  ) async {
    prepared.add(episode.id);
    if (fail) throw StateError('Download failed');
    if (pending != null) await pending!.future;
    onProgress(1);
    return Uri.parse('https://example.com/audio.mp3');
  }

  @override
  Future<void> remove(Episode episode) async {
    if (failCleanup) throw StateError('Cleanup failed');
    removed.add(episode.id);
  }

  @override
  Future<void> removeCompleted(
    List<Episode> episodes,
    Set<String> completed,
  ) async {
    for (final episode in episodes.where((e) => completed.contains(e.id))) {
      await remove(episode);
    }
  }

  @override
  void release() {}
}

class FakeEngine implements AudioEngine {
  final positionEvents = StreamController<Duration>.broadcast(sync: true);
  final playingEvents = StreamController<bool>.broadcast(sync: true);
  final completedEvents = StreamController<void>.broadcast(sync: true);
  Duration? loadedPosition;
  bool stopped = false;
  @override
  Stream<Duration> get positions => positionEvents.stream;
  @override
  Stream<bool> get playingChanges => playingEvents.stream;
  @override
  Stream<bool> get bufferingChanges => const Stream.empty();
  @override
  Stream<void> get completions => completedEvents.stream;
  @override
  Stream<Object> get errors => const Stream.empty();
  @override
  Duration? get duration => const Duration(minutes: 50);
  @override
  Future<void> load(Uri uri, Duration position) async {
    loadedPosition = position;
  }

  @override
  Future<void> play() async {
    playingEvents.add(true);
  }

  @override
  Future<void> pause() async {
    playingEvents.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    positionEvents.add(position);
  }

  @override
  Future<void> stop() async {
    stopped = true;
    playingEvents.add(false);
    positionEvents.add(Duration.zero);
  }

  @override
  Future<void> dispose() async {
    await positionEvents.close();
    await playingEvents.close();
    await completedEvents.close();
  }
}

void main() {
  late MemoryStore store;
  late FakeCache cache;
  late FakeEngine engine;
  late PlayerController player;
  setUp(() {
    store = MemoryStore();
    cache = FakeCache();
    engine = FakeEngine();
  });
  Future<void> initialize() async {
    player = PlayerController(engine: engine, cache: cache, store: store);
    await player.setEpisodes([first, second]);
    addTearDown(player.dispose);
  }

  test('listing episodes never downloads audio', () async {
    await initialize();
    expect(cache.prepared, isEmpty);
    expect(player.resumeEpisode, first);
  });

  test(
    'restores selected episode and position without autoplay or download',
    () async {
      store.value.currentId = second.id;
      store.value.positions[second.id] = 123000;
      await initialize();
      expect(player.current, second);
      expect(player.position, const Duration(seconds: 123));
      expect(player.playing, isFalse);
      expect(cache.prepared, isEmpty);
      await player.playEpisode(second);
      expect(engine.loadedPosition, const Duration(seconds: 123));
      expect(cache.prepared, [second.id]);
    },
  );

  test('position survives pausing and switching episodes', () async {
    await initialize();
    await player.playEpisode(first);
    engine.positionEvents.add(const Duration(seconds: 90));
    await player.togglePlayback();
    expect(store.value.positions[first.id], 90000);
    await player.playEpisode(second);
    await player.playEpisode(first);
    expect(engine.loadedPosition, const Duration(seconds: 90));
  });

  test(
    'natural completion persists finished status and deletes audio',
    () async {
      await initialize();
      await player.playEpisode(first);
      engine.completedEvents.add(null);
      await Future<void>.delayed(Duration.zero);
      await player.save();
      expect(store.value.completed, contains(first.id));
      expect(store.value.positions, isNot(contains(first.id)));
      expect(cache.removed, contains(first.id));
      expect(player.resumeEpisode, second);
      expect(engine.stopped, isTrue);
      engine.positionEvents.add(const Duration(minutes: 50));
      expect(player.state.positions, isNot(contains(first.id)));
    },
  );

  test(
    'replaying a finished episode starts at zero and downloads again',
    () async {
      await initialize();
      await player.playEpisode(first);
      await player.markFinished();
      await player.playEpisode(first);
      expect(cache.prepared, [first.id, first.id]);
      expect(engine.loadedPosition, Duration.zero);
      expect(player.state.completed, isNot(contains(first.id)));
    },
  );

  test('download failures preserve resume progress and allow retry', () async {
    store.value.currentId = first.id;
    store.value.positions[first.id] = 45000;
    cache.fail = true;
    await initialize();
    await player.playEpisode(first);
    expect(player.busy, isFalse);
    expect(player.message, isNotNull);
    expect(store.value.positions[first.id], 45000);
    cache.fail = false;
    await player.playEpisode(first);
    expect(engine.loadedPosition, const Duration(seconds: 45));
  });

  test('finished-cache cleanup is retried on startup', () async {
    store.value.completed.add(first.id);
    await initialize();
    expect(cache.removed, [first.id]);
    expect(cache.prepared, isEmpty);
  });

  test('cleanup failures do not undo completion', () async {
    await initialize();
    await player.playEpisode(first);
    cache.failCleanup = true;
    await player.markFinished();
    expect(store.value.completed, contains(first.id));
    expect(player.warning, isNotNull);
    expect(player.busy, isFalse);
  });

  test('storage failures are surfaced without breaking playback', () async {
    await initialize();
    store.fail = true;
    await player.playEpisode(first);
    expect(player.playing, isTrue);
    expect(player.warning, contains('kan niet worden opgeslagen'));
  });

  test('does not allow overlapping episode downloads', () async {
    await initialize();
    cache.pending = Completer<void>();
    final load = player.playEpisode(first);
    await Future<void>.delayed(Duration.zero);
    await player.playEpisode(second);
    expect(cache.prepared, [first.id]);
    cache.pending!.complete();
    await load;
    expect(player.current, first);
  });

  test('seeks are clamped and persisted', () async {
    await initialize();
    await player.playEpisode(first);
    await player.seek(const Duration(seconds: -15));
    expect(player.position, Duration.zero);
    await player.seek(const Duration(hours: 2));
    expect(player.position, const Duration(minutes: 50));
    expect(store.value.positions[first.id], 3000000);
  });
}
