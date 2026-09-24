import 'package:flutter_test/flutter_test.dart';
import 'package:sendsar_chat_uikit/src/utils/format_time.dart';

void main() {
  test('formatRelativeTime returns empty for null', () {
    expect(formatRelativeTime(null), '');
  });

  test('formatRelativeTime returns now for recent timestamps', () {
    final now = DateTime.now().toUtc().toIso8601String();
    expect(formatRelativeTime(now), 'now');
  });

  test('formatMessageHeaderTime uses 12-hour clock', () {
    expect(
      formatMessageHeaderTime('2024-01-15T21:57:00.000Z'),
      isNot(isEmpty),
    );
    final label = formatMessageHeaderTime('2024-01-15T09:05:00');
    expect(label, contains(':'));
    expect(label == '9:05 AM' || label.endsWith('AM') || label.endsWith('PM'), isTrue);
  });
}
