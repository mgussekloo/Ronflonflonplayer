import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/episode.dart';
import '../models/listening_state.dart';
import '../services/audio_cache.dart';
import '../services/library_repository.dart';
import 'audio_engine.dart';

class PlayerController extends ChangeNotifier {
  PlayerController({
    required this.engine,
    required this.cache,
    required this.store,
  }) {
    try {
      state = store.read();
    } catch (_) {
      state = ListeningState();
      _canSave = false;
      warning =
          'Je opgeslagen luisterpositie kan niet worden gelezen. Bestaande gegevens worden niet overschreven.';
    }
    _subscriptions.addAll([
      engine.positions.listen(_onPosition),
      engine.playingChanges.listen((value) {
        playing = value;
        _notify();
      }),
      engine.bufferingChanges.listen((value) {
        buffering = value;
        _notify();
      }),
      engine.completions.listen((_) {
        unawaited(markFinished());
      }),
      engine.errors.listen((error) {
        debugPrint('Afspelen mislukt: $error');
        message =
            'Afspelen mislukt. Probeer de uitzending opnieuw af te spelen.';
        _notify();
      }),
    ]);
  }

  final AudioEngine engine;
  final AudioCache cache;
  final ProgressStore store;
  late final ListeningState state;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<Episode> episodes = [];
  bool playing = false;
  bool buffering = false;
  bool busy = false;
  bool _loaded = false;
  bool _disposed = false;
  bool _canSave = true;
  double? downloadProgress;
  String? message;
  String? warning;
  Duration position = Duration.zero;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _writes = Future.value();

  Episode? get current {
    for (final episode in episodes) {
      if (episode.id == state.currentId) return episode;
    }
    return null;
  }

  Episode? get resumeEpisode {
    final selected = current;
    if (selected != null && !state.completed.contains(selected.id)) {
      return selected;
    }
    for (final episode in episodes) {
      if (!state.completed.contains(episode.id)) return episode;
    }
    return null;
  }

  bool get canSeek => _loaded && !busy;

  Duration get duration => _loaded
      ? (engine.duration ?? current?.duration ?? Duration.zero)
      : current?.duration ?? Duration.zero;

  Future<void> setEpisodes(List<Episode> value) async {
    busy = true;
    episodes = value;
    position = current == null ? Duration.zero : state.positionFor(current!.id);
    _notify();
    try {
      await cache.removeCompleted(episodes, state.completed);
    } catch (_) {
      warning =
          'Sommige beluisterde opnamen kunnen niet worden verwijderd. Bij de volgende keer proberen we het opnieuw.';
      _notify();
    } finally {
      busy = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _onPosition(Duration value) {
    final episode = current;
    if (!_loaded ||
        busy ||
        episode == null ||
        state.completed.contains(episode.id)) {
      return;
    }
    position = value;
    state.positions[episode.id] = value.inMilliseconds;
    if (DateTime.now().difference(_lastSave) >= const Duration(seconds: 2)) {
      unawaited(save());
    }
    _notify();
  }

  Future<void> save() {
    if (!_canSave) return Future.value();
    _lastSave = DateTime.now();
    // Snapshot and serialize writes so an older position cannot win a race.
    final snapshot = ListeningState.fromJson(state.toJson());
    _writes = _writes.then((_) => store.write(snapshot)).catchError((
      Object error,
    ) {
      warning =
          'Je luisterpositie kan niet worden opgeslagen. De browseropslag is mogelijk vol of uitgeschakeld.';
      _notify();
    });
    return _writes;
  }

  Future<void> playEpisode(Episode episode) async {
    if (busy || _disposed) return;
    if (current?.id == episode.id &&
        _loaded &&
        !state.completed.contains(episode.id)) {
      _startPlayback();
      return;
    }
    busy = true;
    message = null;
    downloadProgress = null;
    _notify();
    try {
      await engine.pause();
      await save();
      _loaded = false;
      await engine.stop();
      cache.release();
      state.currentId = episode.id;
      position = state.completed.contains(episode.id)
          ? Duration.zero
          : state.positionFor(episode.id);
      await save();
      _notify();
      final uri = await cache.prepare(episode, (value) {
        downloadProgress = value;
        _notify();
      });
      if (_disposed) {
        cache.release();
        return;
      }
      // Leave a small margin if an archive duration changed since the last visit.
      if (episode.duration > Duration.zero && position >= episode.duration) {
        position = Duration.zero;
      }
      await engine.load(uri, position);
      state.completed.remove(episode.id);
      state.positions[episode.id] = position.inMilliseconds;
      _loaded = true;
      await save();
      _startPlayback();
    } catch (error) {
      debugPrint('Uitzending laden mislukt: $error');
      message =
          'Deze uitzending kan niet worden geladen. Controleer je internetverbinding en beschikbare opslagruimte en probeer het opnieuw.';
      cache.release();
    } finally {
      busy = false;
      _notify();
    }
  }

  void _startPlayback() {
    // just_audio's play Future lasts until pause/end; do not await it as a load.
    unawaited(
      engine.play().catchError((Object error) {
        debugPrint('Afspelen geblokkeerd of mislukt: $error');
        message =
            'Afspelen is geblokkeerd of mislukt. Druk op de afspeelknop om het opnieuw te proberen.';
        _notify();
      }),
    );
  }

  Future<void> togglePlayback() async {
    if (busy) return;
    if (playing) {
      try {
        await engine.pause();
        await save();
      } catch (error) {
        debugPrint('Pauzeren mislukt: $error');
        message =
            'Het afspelen kan niet worden gepauzeerd. Probeer het opnieuw.';
        _notify();
      }
    } else {
      final episode = current ?? resumeEpisode;
      if (episode != null) await playEpisode(episode);
    }
  }

  Future<void> seek(Duration value) async {
    if (busy || !_loaded) return;
    final target = Duration(
      milliseconds: value.inMilliseconds.clamp(
        0,
        duration > Duration.zero
            ? duration.inMilliseconds
            : value.inMilliseconds.clamp(0, 9007199254740),
      ),
    );
    try {
      await engine.seek(target);
      position = target;
      if (current != null) state.positions[current!.id] = target.inMilliseconds;
      await save();
      _notify();
    } catch (error) {
      debugPrint('Naar een andere luisterpositie gaan mislukt: $error');
      message =
          'Je kunt nu niet naar een andere luisterpositie gaan. Probeer het opnieuw.';
      _notify();
    }
  }

  Future<void> markFinished() async {
    final episode = current;
    if (busy || episode == null || state.completed.contains(episode.id)) return;
    busy = true;
    _loaded = false;
    state.completed.add(episode.id);
    state.positions.remove(episode.id);
    position = Duration.zero;
    _notify();
    await save();
    try {
      await engine.stop();
      cache.release();
      await cache.remove(episode);
    } catch (_) {
      warning =
          'De uitzending is gemarkeerd als beluisterd, maar de audio kan niet worden verwijderd. Bij de volgende keer proberen we het opnieuw.';
    } finally {
      playing = false;
      busy = false;
      _notify();
    }
  }

  Future<void> markUnfinished(Episode episode) async {
    if (busy) return;
    state.completed.remove(episode.id);
    await save();
    _notify();
  }

  @override
  void dispose() {
    unawaited(save());
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(engine.dispose().whenComplete(cache.release));
    super.dispose();
  }
}
