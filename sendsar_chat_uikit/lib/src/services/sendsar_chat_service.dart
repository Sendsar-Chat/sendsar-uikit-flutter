import 'dart:typed_data';

import 'package:sendsar_chat/sendsar_chat.dart';

import 'sendsar_session_service.dart';

class SendsarChatService {
  SendsarChatService(this._session);

  final SendsarSessionService _session;

  SendsarClient requireClient() {
    final client = _session.client;
    if (client == null) {
      throw StateError('Sendsar client is not connected');
    }
    return client;
  }

  Future<RoomsResponse> listRooms([
    ListRoomsParams params = const ListRoomsParams(),
  ]) =>
      requireClient().listRooms(params);

  Future<MessagesResponse> getMessages(
    String roomId, [
    ListMessagesParams params = const ListMessagesParams(),
  ]) =>
      requireClient().getMessages(roomId, params);

  Future<Message> sendMessage(String roomId, SendMessageParams params) =>
      requireClient().sendMessage(roomId, params);

  Future<Message> updateMessage(
    String roomId,
    String messageId,
    UpdateMessageParams params,
  ) =>
      requireClient().updateMessage(roomId, messageId, params);

  Future<Message> deleteMessage(String roomId, String messageId) =>
      requireClient().deleteMessage(roomId, messageId);

  Future<Message> toggleReaction(
    String roomId,
    String messageId,
    ToggleReactionParams params,
  ) =>
      requireClient().toggleReaction(roomId, messageId, params);

  Future<Message> sendFileMessage(
    String roomId, {
    required List<int> bytes,
    required String filename,
    required String mediaType,
    String? clientMessageId,
    String? parentMessageId,
    String? senderId,
  }) =>
      requireClient().sendFileMessage(
        roomId,
        bytes: Uint8List.fromList(bytes),
        filename: filename,
        mediaType: mediaType,
        clientMessageId: clientMessageId,
        parentMessageId: parentMessageId,
        senderId: senderId,
      );
}
