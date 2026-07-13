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
}
