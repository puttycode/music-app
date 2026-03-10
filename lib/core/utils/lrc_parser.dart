class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine({required this.timestamp, required this.text});
}

class LrcParser {
  static List<LyricLine> parse(String lrcContent) {
    final List<LyricLine> lyrics = [];
    final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    
    for (final line in lrcContent.split('\n')) {
      final match = regex.firstMatch(line);
      if (match != null) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final millisStr = match.group(3)!;
        final millis = int.parse(millisStr.padRight(3, '0'));
        final text = match.group(4)!.trim();
        
        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: millis,
        );
        
        if (text.isNotEmpty) {
          lyrics.add(LyricLine(timestamp: timestamp, text: text));
        }
      }
    }
    
    return lyrics;
  }

  static int findCurrentLineIndex(List<LyricLine> lyrics, Duration position) {
    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (position >= lyrics[i].timestamp) {
        return i;
      }
    }
    return 0;
  }
}
