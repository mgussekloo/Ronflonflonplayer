class ListeningState {
  ListeningState({
    this.currentId,
    Map<String, int>? positions,
    Set<String>? completed,
  }) : positions = positions ?? {},
       completed = completed ?? {};

  String? currentId;
  final Map<String, int> positions;
  final Set<String> completed;

  Duration positionFor(String id) => Duration(milliseconds: positions[id] ?? 0);

  factory ListeningState.fromJson(Map<String, dynamic> json) {
    final positions = <String, int>{};
    final raw = json['positions'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String &&
            entry.value is num &&
            (entry.value as num).isFinite) {
          positions[entry.key as String] = (entry.value as num).toInt().clamp(
            0,
            9007199254740,
          );
        }
      }
    }
    return ListeningState(
      currentId: json['currentId'] is String
          ? json['currentId'] as String
          : null,
      positions: positions,
      completed: (json['completed'] is List ? json['completed'] as List : [])
          .whereType<String>()
          .toSet(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'currentId': currentId,
    'positions': positions,
    'completed': completed.toList(),
  };
}
