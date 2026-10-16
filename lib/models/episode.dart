const archiveIdentifier = 'ronflonflon-119-1987-01-14-ps-2760';

class Episode {
  const Episode({
    required this.fileName,
    required this.number,
    this.suffix = '',
    this.date,
    this.duration = Duration.zero,
    this.bytes = 0,
  });

  final String fileName;
  final int number;
  final String suffix;
  final DateTime? date;
  final Duration duration;
  final int bytes;

  // File names, unlike the archive's track tags, are stable episode identities.
  String get id => fileName;
  String get label => 'Uitzending ${number.toString().padLeft(3, '0')}$suffix';
  Uri get audioUri =>
      Uri.https('archive.org', '/download/$archiveIdentifier/$fileName');

  static List<Episode> fromMetadata(Map<String, dynamic> metadata) {
    final files =
        (metadata['files'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .where(
              (file) => (file['name'] as String? ?? '').toLowerCase().endsWith(
                '.mp3',
              ),
            )
            .toList()
          ..sort(
            (a, b) => (a['name'] as String).length.compareTo(
              (b['name'] as String).length,
            ),
          );
    final hashes = <String>{};
    final episodes = <Episode>[];
    for (final file in files) {
      final name = file['name'] as String;
      final match = RegExp(
        r'^Ronflonflon\s+(\d+)([a-z]?)',
        caseSensitive: false,
      ).firstMatch(name);
      if (match == null) continue;
      final hash = file['md5'] as String?;
      if (hash != null && hash.isNotEmpty && !hashes.add(hash)) continue;
      final seconds = double.tryParse('${file['length']}') ?? 0;
      episodes.add(
        Episode(
          fileName: name,
          number: int.parse(match[1]!),
          suffix: match[2]!.toLowerCase(),
          date: _dateFromName(name),
          duration: Duration(
            milliseconds: seconds.isFinite && seconds > 0
                ? (seconds * 1000).round()
                : 0,
          ),
          bytes: int.tryParse('${file['size']}') ?? 0,
        ),
      );
    }
    episodes.sort((a, b) {
      final number = a.number.compareTo(b.number);
      if (number != 0) return number;
      final suffix = a.suffix.compareTo(b.suffix);
      return suffix != 0 ? suffix : a.fileName.compareTo(b.fileName);
    });
    return episodes;
  }

  static DateTime? _dateFromName(String name) {
    var match = RegExp(
      r'((?:19|20)\d{2})[-_](\d{1,2})[-_](\d{1,2})',
    ).firstMatch(name);
    if (match != null) {
      return _validDate(
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
      );
    }
    match = RegExp(
      r'(?:_|-)[ ]?((?:19|20)?\d{6})(?:[A-Z_\-.])',
    ).firstMatch(name);
    if (match != null) {
      final digits = match[1]!;
      final yearLength = digits.length - 4;
      final year = int.parse(digits.substring(0, yearLength));
      return _validDate(
        yearLength == 2 ? 1900 + year : year,
        int.parse(digits.substring(yearLength, yearLength + 2)),
        int.parse(digits.substring(yearLength + 2)),
      );
    }
    return null; // Do not invent dates for malformed archive filenames.
  }

  static DateTime? _validDate(int year, int month, int day) {
    final value = DateTime(year, month, day);
    return value.year == year && value.month == month && value.day == day
        ? value
        : null;
  }
}
