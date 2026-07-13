import 'package:flutter_test/flutter_test.dart';
import 'package:sendsar_chat_uikit/src/utils/emoji_segments.dart';

void main() {
  test('segmentTextWithEmoji splits emoji graphemes', () {
    final segments = segmentTextWithEmoji('Hi 👋 there');
    expect(segments.length, 3);
    expect(segments[0], isA<PlainTextSegment>());
    expect((segments[0] as PlainTextSegment).value, 'Hi ');
    expect(segments[1], isA<EmojiTextSegment>());
    expect((segments[1] as EmojiTextSegment).value, '👋');
    expect((segments[2] as PlainTextSegment).value, ' there');
  });
}
