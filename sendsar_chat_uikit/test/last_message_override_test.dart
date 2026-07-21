import 'package:flutter_test/flutter_test.dart';
import 'package:sendsar_chat/sendsar_chat.dart';
import 'package:sendsar_chat_uikit/sendsar_chat_uikit.dart';

RoomSummary _room({({String? previewText, String createdAt})? lastMessage}) {
  return RoomSummary(
    id: 'room-1',
    name: 'Room',
    externalId: null,
    customType: null,
    metadata: null,
    isFrozen: false,
    lastMessage: lastMessage,
    createdAt: '2026-07-20T00:00:00.000Z',
  );
}

void main() {
  group('effectiveLastMessage', () {
    test('no override falls back to server lastMessage', () {
      final result = effectiveLastMessage(
        _room(
          lastMessage: (
            previewText: 'Hello',
            createdAt: '2026-07-21T01:00:00.000Z',
          ),
        ),
        null,
      );
      expect(result.preview, 'Hello');
      expect(result.createdAt, '2026-07-21T01:00:00.000Z');
    });

    test('newer override wins over stale server data', () {
      final result = effectiveLastMessage(
        _room(
          lastMessage: (
            previewText: 'Old text',
            createdAt: '2026-07-21T01:00:00.000Z',
          ),
        ),
        (preview: 'Voice call · 0:42', createdAt: '2026-07-21T02:00:00.000Z'),
      );
      expect(result.preview, 'Voice call · 0:42');
      expect(result.createdAt, '2026-07-21T02:00:00.000Z');
    });

    test('older override is ignored', () {
      final result = effectiveLastMessage(
        _room(
          lastMessage: (
            previewText: 'Fresh from server',
            createdAt: '2026-07-21T03:00:00.000Z',
          ),
        ),
        (preview: 'Stale override', createdAt: '2026-07-21T02:00:00.000Z'),
      );
      expect(result.preview, 'Fresh from server');
      expect(result.createdAt, '2026-07-21T03:00:00.000Z');
    });

    test('tie prefers the override', () {
      final result = effectiveLastMessage(
        _room(
          lastMessage: (
            previewText: null,
            createdAt: '2026-07-21T02:00:00.000Z',
          ),
        ),
        (preview: 'Missed voice call', createdAt: '2026-07-21T02:00:00.000Z'),
      );
      expect(result.preview, 'Missed voice call');
    });

    test('override wins when server has no lastMessage', () {
      final result = effectiveLastMessage(
        _room(lastMessage: null),
        (preview: 'Video call · 1:05', createdAt: '2026-07-21T02:00:00.000Z'),
      );
      expect(result.preview, 'Video call · 1:05');
      expect(result.createdAt, '2026-07-21T02:00:00.000Z');
    });

    test('newerOverride picks the fresher of two snapshots', () {
      const older = (preview: 'old', createdAt: '2026-07-21T01:00:00.000Z');
      const newer = (preview: 'new', createdAt: '2026-07-21T02:00:00.000Z');
      expect(newerOverride(older, newer), newer);
      expect(newerOverride(newer, older), newer);
      expect(newerOverride(null, older), older);
      expect(newerOverride(older, null), older);
      expect(newerOverride(null, null), isNull);
    });

    test('unparseable override timestamp falls back to server', () {
      final result = effectiveLastMessage(
        _room(
          lastMessage: (
            previewText: 'Server',
            createdAt: '2026-07-21T01:00:00.000Z',
          ),
        ),
        (preview: 'Broken', createdAt: 'not-a-date'),
      );
      expect(result.preview, 'Server');
    });
  });
}
