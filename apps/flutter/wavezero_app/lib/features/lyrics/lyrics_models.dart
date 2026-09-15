class WzLyricLine {
  const WzLyricLine({required this.timeMs, required this.text});

  final int timeMs;
  final String text;
}

class WzLyricsDocument {
  const WzLyricsDocument({
    required this.trackId,
    required this.rawText,
    required this.updatedAtMs,
  });

  final String trackId;
  final String rawText;
  final int updatedAtMs;

  bool get isEmpty => rawText.trim().isEmpty;

  List<WzLyricLine> get syncedLines => parseWzLrc(rawText);

  bool get isSynced => syncedLines.isNotEmpty;

  int activeLineIndex(int positionMs) {
    final lines = syncedLines;
    if (lines.isEmpty) return -1;
    var low = 0;
    var high = lines.length - 1;
    var answer = -1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (lines[mid].timeMs <= positionMs) {
        answer = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return answer;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'trackId': trackId,
        'rawText': rawText,
        'updatedAtMs': updatedAtMs,
      };

  factory WzLyricsDocument.fromJson(Map<String, Object?> json) {
    final trackId = json['trackId'];
    final rawText = json['rawText'];
    final updatedAtMs = json['updatedAtMs'];
    if (trackId is! String || trackId.trim().isEmpty || rawText is! String) {
      throw const FormatException('Invalid lyrics document');
    }
    return WzLyricsDocument(
      trackId: trackId,
      rawText: rawText,
      updatedAtMs: updatedAtMs is num ? updatedAtMs.toInt() : 0,
    );
  }
}

final RegExp _wzLrcTimestamp = RegExp(
  r'\[(\d{1,3}):(\d{2})(?:[\.:](\d{1,3}))?\]',
);

List<WzLyricLine> parseWzLrc(String rawText) {
  final parsed = <WzLyricLine>[];
  for (final rawLine in rawText.split(RegExp(r'\r?\n'))) {
    final matches = _wzLrcTimestamp.allMatches(rawLine).toList(growable: false);
    if (matches.isEmpty) continue;
    final text = rawLine.replaceAll(_wzLrcTimestamp, '').trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
      final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
      final fractionRaw = match.group(3) ?? '';
      var fractionMs = 0;
      if (fractionRaw.isNotEmpty) {
        final fraction = int.tryParse(fractionRaw) ?? 0;
        fractionMs = switch (fractionRaw.length) {
          1 => fraction * 100,
          2 => fraction * 10,
          _ => fractionRaw.length > 3
              ? int.tryParse(fractionRaw.substring(0, 3)) ?? 0
              : fraction,
        };
      }
      parsed.add(
        WzLyricLine(
          timeMs: ((minutes * 60) + seconds) * 1000 + fractionMs,
          text: text,
        ),
      );
    }
  }
  parsed.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return parsed;
}
