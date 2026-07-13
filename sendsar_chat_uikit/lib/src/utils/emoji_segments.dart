import 'package:characters/characters.dart';

sealed class TextSegment {
  const TextSegment();
}

class PlainTextSegment extends TextSegment {
  const PlainTextSegment(this.value);
  final String value;
}

class EmojiTextSegment extends TextSegment {
  const EmojiTextSegment(this.value);
  final String value;
}

bool _looksLikeEmoji(String segment) {
  if (segment.isEmpty) return false;
  final cp = segment.runes.first;
  return cp >= 0x1F000 ||
      cp == 0x2764 ||
      cp == 0x2763 ||
      (cp >= 0x2600 && cp <= 0x27BF) ||
      (cp >= 0x1F1E6 && cp <= 0x1F1FF);
}

/// Split message text into plain text runs and emoji graphemes.
List<TextSegment> segmentTextWithEmoji(String text) {
  if (text.isEmpty) return [];

  final segments = <TextSegment>[];
  var buffer = '';

  for (final match in text.characters) {
    if (_looksLikeEmoji(match)) {
      if (buffer.isNotEmpty) {
        segments.add(PlainTextSegment(buffer));
        buffer = '';
      }
      segments.add(EmojiTextSegment(match));
    } else {
      buffer += match;
    }
  }

  if (buffer.isNotEmpty) {
    segments.add(PlainTextSegment(buffer));
  }

  return segments.isEmpty ? [PlainTextSegment(text)] : segments;
}
