import 'package:just_audio/just_audio.dart';

abstract interface class AudioEngine {
  Stream<Duration> get positions;
  Stream<bool> get playingChanges;
  Stream<bool> get bufferingChanges;
  Stream<void> get completions;
  Stream<Object> get errors;
  Duration? get duration;
  Future<void> load(Uri uri, Duration position);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioEngine implements AudioEngine {
  final AudioPlayer _player = AudioPlayer();
  @override
  Stream<Duration> get positions => _player.positionStream;
  @override
  Stream<bool> get playingChanges =>
      _player.playerStateStream.map((s) => s.playing).distinct();
  @override
  Stream<bool> get bufferingChanges => _player.playerStateStream
      .map(
        (s) =>
            s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering,
      )
      .distinct();
  @override
  Stream<void> get completions => _player.playerStateStream
      .where((s) => s.processingState == ProcessingState.completed)
      .map((_) {});
  @override
  Stream<Object> get errors => _player.errorStream;
  @override
  Duration? get duration => _player.duration;
  @override
  Future<void> load(Uri uri, Duration position) async {
    await _player.setAudioSource(
      AudioSource.uri(uri),
      initialPosition: position,
    );
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}
