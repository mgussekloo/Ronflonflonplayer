import 'dart:js_interop';
import '../models/episode.dart';
import 'audio_cache.dart';

@JS('ronflonflonCache.prepare')
external JSPromise<JSString> _prepare(JSString url, JSFunction progress);
@JS('ronflonflonCache.remove')
external JSPromise<JSAny?> _remove(JSString url);
@JS('ronflonflonCache.release')
external void _release();

AudioCache createAudioCache() => BrowserAudioCache();

class BrowserAudioCache implements AudioCache {
  @override
  Future<Uri> prepare(
    Episode episode,
    void Function(double?) onProgress,
  ) async {
    final callback = ((JSNumber progress) {
      final value = progress.toDartDouble;
      onProgress(value < 0 ? null : value);
    }).toJS;
    final url = await _prepare(
      episode.audioUri.toString().toJS,
      callback,
    ).toDart;
    return Uri.parse(url.toDart);
  }

  @override
  Future<void> remove(Episode episode) async {
    await _remove(episode.audioUri.toString().toJS).toDart;
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
  void release() => _release();
}
