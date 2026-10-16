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
          'Saved progress could not be read. Existing data will not be overwritten.';
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
        message = 'Playback failed. Try playing the episode again. $error';
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
          'Some finished audio could not be removed. Cleanup will be retried next time.';
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
          'Progress could not be saved. Browser storage may be full or disabled.';
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
      message =
          'Could not load this episode. Check your connection and available storage, then retry. $error';
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
        message =
            'Playback was blocked or failed. Press play to try again. $error';
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
        message = 'Could not pause playback. $error';
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
      message = 'Could not seek. $error';
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
          'Episode marked finished, but audio cleanup failed. It will be retried next time.';
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
