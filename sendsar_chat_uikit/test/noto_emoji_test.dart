import 'package:flutter_test/flutter_test.dart';
import 'package:sendsar_chat_uikit/src/utils/noto_emoji.dart';

void main() {
  test('emojiToCodepointKey joins codepoints', () {
    expect(emojiToCodepointKey('👋'), '1f44b');
    expect(
      notoLottieUrl('👋'),
      'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44b/lottie.json',
    );
    expect(
      notoEmojiPngUrl('👋'),
      'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44b/72.png',
    );
    expect(
      notoEmojiPngUrl('👋', size: 28),
      'https://fonts.gstatic.com/s/e/notoemoji/latest/1f44b/32.png',
    );
  });
}
