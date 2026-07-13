import 'package:flutter_test/flutter_test.dart';
import 'package:sendsar_chat/sendsar_chat.dart';
import 'package:sendsar_chat_uikit/src/utils/room_label.dart';
import 'package:sendsar_chat_uikit/src/utils/user_directory.dart';

RoomSummary _room({
  String? name,
  String? externalId,
  String? customType,
}) {
  return RoomSummary(
    id: 'room-1',
    name: name,
    externalId: externalId,
    customType: customType,
    metadata: null,
    isFrozen: false,
    lastMessage: null,
    createdAt: '2026-01-01T00:00:00.000Z',
  );
}

void main() {
  const users = [
    UserDirectoryEntry(id: 'usr_a', displayName: 'Alice'),
    UserDirectoryEntry(id: 'usr_b', displayName: 'Bob'),
  ];

  test('resolveRoomLabel shows peer name for DM external id', () {
    final label = resolveRoomLabel(
      _room(externalId: 'dm:usr_a:usr_b', customType: 'demo_dm'),
      'usr_a',
      users,
    );
    expect(label, 'Bob');
  });

  test('parseDmPeerId returns other participant', () {
    expect(parseDmPeerId('dm:usr_a:usr_b', 'usr_a'), 'usr_b');
  });
}
