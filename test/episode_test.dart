import 'package:flutter_test/flutter_test.dart';
import 'package:ronflonflon_player/models/episode.dart';

void main() {
  test(
    'sorts by filename episode number, not unreliable track or date tags',
    () {
      final episodes = Episode.fromMetadata({
        'files': [
          {
            'name': 'Ronflonflon 030 - 1985-05-01.mp3',
            'track': '29',
            'length': '3250.5',
          },
          {'name': 'Ronflonflon 002-1984-10-17.mp3', 'track': '100'},
          {'name': 'Ronflonflon 001-NA124884-1984-10-10-1715.mp3'},
          {'name': 'Ronflonflon 002.png'},
          {'name': 'other.mp3'},
        ],
      });
      expect(episodes.map((e) => e.number), [1, 2, 30]);
      expect(episodes.first.date, DateTime(1984, 10, 10));
      expect(episodes.last.duration, const Duration(milliseconds: 3250500));
    },
  );

  test(
    'removes exact duplicate uploads and prefers the shorter original name',
    () {
      final episodes = Episode.fromMetadata({
        'files': [
          {'name': 'Ronflonflon 143 - 1987-07-01(1).mp3', 'md5': 'same'},
          {'name': 'Ronflonflon 143 - 1987-07-01.mp3', 'md5': 'same'},
          {'name': 'Ronflonflon 144 - 1987-07-08.mp3', 'md5': 'other'},
        ],
      });
      expect(episodes, hasLength(2));
      expect(episodes.first.fileName, isNot(contains('(1)')));
    },
  );

  test('keeps letter-suffixed episodes and missing-number gaps', () {
    final episodes = Episode.fromMetadata({
      'files': [
        {'name': 'Ronflonflon 261 - 1989-10-04.mp3'},
        {'name': 'Ronflonflon 260b_NA67717_19890927_2852.mp3'},
        {'name': 'Ronflonflon 260 - 1989-09-20.mp3'},
        {'name': 'Ronflonflon 258 - 1989-09-06.mp3'},
      ],
    });
    expect(episodes.map((e) => e.label), [
      'Episode 258',
      'Episode 260',
      'Episode 260b',
      'Episode 261',
    ]);
    expect(episodes[2].date, DateTime(1989, 9, 27));
  });

  test(
    'parses underscore and compact dates; does not invent malformed dates',
    () {
      final episodes = Episode.fromMetadata({
        'files': [
          {'name': 'Ronflonflon 010_1984_12_12_.mp3'},
          {'name': 'Ronflonflon 108 - 1096-10-29.mp3'},
          {'name': 'Ronflonflon 247_890628F.mp3'},
          {'name': 'Ronflonflon 276-900117F.mp3'},
          {'name': 'Ronflonflon 329_23_1_91.mp3'},
        ],
      });
      expect(episodes[0].date, DateTime(1984, 12, 12));
      expect(episodes[1].date, isNull);
      expect(episodes[2].date, DateTime(1989, 6, 28));
      expect(episodes[3].date, DateTime(1990, 1, 17));
      expect(episodes[4].date, isNull);
    },
  );

  test('download URLs preserve and encode the actual archive filename', () {
    const episode = Episode(
      fileName: 'Ronflonflon 012 - test #1.mp3',
      number: 12,
    );
    expect(episode.audioUri.host, 'archive.org');
    expect(episode.audioUri.pathSegments.last, episode.fileName);
    expect(episode.audioUri.fragment, isEmpty);
  });
}
