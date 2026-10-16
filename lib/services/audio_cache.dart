import '../models/episode.dart';
import 'audio_cache_stub.dart'
    if (dart.library.js_interop) 'audio_cache_web.dart'
    if (dart.library.io) 'audio_cache_native.dart'
    as platform;

abstract interface class AudioCache {
  Future<Uri> prepare(Episode episode, void Function(double?) onProgress);
  Future<void> remove(Episode episode);
  Future<void> removeCompleted(List<Episode> episodes, Set<String> completed);
  void release();
}

AudioCache createAudioCache() => platform.createAudioCache();
