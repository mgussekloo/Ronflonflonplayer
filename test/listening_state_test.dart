import 'package:flutter_test/flutter_test.dart';
import 'package:ronflonflon_player/models/listening_state.dart';

void main() {
  test('progress round trips, including completed episodes', () {
    final state = ListeningState(
      currentId: 'episode.mp3',
      positions: {'episode.mp3': 12345},
      completed: {'finished.mp3'},
    );
    final restored = ListeningState.fromJson(state.toJson());
    expect(restored.currentId, state.currentId);
    expect(
      restored.positionFor('episode.mp3'),
      const Duration(milliseconds: 12345),
    );
    expect(restored.completed, {'finished.mp3'});
  });
  test('ignores invalid fields and clamps negative positions', () {
    final state = ListeningState.fromJson({
      'currentId': 42,
      'positions': {'negative': -9, 'invalid': 'oops'},
      'completed': ['valid', 7],
    });
    expect(state.currentId, isNull);
    expect(state.positionFor('negative'), Duration.zero);
    expect(state.positions.containsKey('invalid'), isFalse);
    expect(state.completed, {'valid'});
  });
}
