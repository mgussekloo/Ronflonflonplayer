import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/episode.dart';
import 'audio_cache.dart';

AudioCache createAudioCache() => NativeAudioCache();

class NativeAudioCache implements AudioCache {
  Future<File> _file(Episode episode) async {
    final root = await getApplicationSupportDirectory();
    final directory = await Directory(
      '${root.path}/episodes',
    ).create(recursive: true);
    return File('${directory.path}/${Uri.encodeComponent(episode.fileName)}');
  }

  @override
  Future<Uri> prepare(
    Episode episode,
    void Function(double?) onProgress,
  ) async {
    final file = await _file(episode);
    if (await file.exists()) return file.uri;
    final temporary = File('${file.path}.part');
    final client = http.Client();
    final sink = temporary.openWrite();
    try {
      final response = await client
          .send(http.Request('GET', episode.audioUri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('Download returned ${response.statusCode}');
      }
      var received = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 60),
      )) {
        sink.add(chunk);
        received += chunk.length;
        final total = response.contentLength;
        onProgress(
          total == null || total <= 0 ? null : (received / total).clamp(0, 1),
        );
      }
      await sink.flush();
      await sink.close();
      await temporary.rename(file.path);
      return file.uri;
    } catch (_) {
      await sink.close();
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  @override
  Future<void> remove(Episode episode) async {
    final file = await _file(episode);
    if (await file.exists()) await file.delete();
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
