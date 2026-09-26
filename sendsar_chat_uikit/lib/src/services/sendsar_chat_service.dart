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

  Future<RoomDetail> getRoom(String roomId) => requireClient().getRoom(roomId);

  Future<RoomDetail> addParticipant(String roomId, AddParticipantParams params) =>
      requireClient().addParticipant(roomId, params);

  Future<RoomDetail> removeParticipant(
    String roomId,
    String userId, [
    RemoveParticipantParams params = const RemoveParticipantParams(),
  ]) =>
      requireClient().removeParticipant(roomId, userId, params);

  Future<DeleteConversationResult> deleteConversation(String roomId) =>
      requireClient().deleteConversation(roomId);

  Future<ClearHistoryResult> clearHistory(String roomId) =>
      requireClient().clearHistory(roomId);

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

  Future<Message> pinMessage(String roomId, String messageId) =>
      requireClient().pinMessage(roomId, messageId);

  Future<Message> unpinMessage(String roomId, String messageId) =>
      requireClient().unpinMessage(roomId, messageId);

  Future<List<Message>> getPinnedMessages(String roomId) =>
      requireClient().getPinnedMessages(roomId);

  Future<List<Message>> forwardMessage(
    String roomId,
    String messageId,
    List<String> targetRoomIds,
  ) =>
      requireClient().forwardMessage(
        roomId,
        messageId,
        ForwardMessageParams(targetRoomIds: targetRoomIds),
      );

  Future<UploadFileResult> uploadFile(
    String roomId, {
    required List<int> bytes,
    required String filename,
    required String mediaType,
  }) =>
      requireClient().uploadFile(
        UploadFileParams(
          bytes: Uint8List.fromList(bytes),
          filename: filename,
          mediaType: mediaType,
          roomId: roomId,
        ),
      );

  /// Upload a file and send it as a message. Optional [text] is a caption
  /// attached in the same message (parity with Angular UI Kit).
  Future<Message> sendFileMessage(
    String roomId, {
    required List<int> bytes,
    required String filename,
    required String mediaType,
    String? text,
    String? clientMessageId,
    String? parentMessageId,
    String? senderId,
  }) async {
    final caption = text?.trim();
    if (caption == null || caption.isEmpty) {
      return requireClient().sendFileMessage(
        roomId,
        bytes: Uint8List.fromList(bytes),
        filename: filename,
        mediaType: mediaType,
        clientMessageId: clientMessageId,
        parentMessageId: parentMessageId,
        senderId: senderId,
      );
    }

    final uploaded = await uploadFile(
      roomId,
      bytes: bytes,
      filename: filename,
      mediaType: mediaType,
    );
    return sendMessage(
      roomId,
      SendMessageParams(
        senderId: senderId,
        clientMessageId: clientMessageId,
        parentMessageId: parentMessageId,
        parts: [
          MessagePart(
            type: 'file',
            uploadId: uploaded.uploadId,
            mediaType: uploaded.mediaType,
            filename: uploaded.filename,
          ),
          MessagePart(type: 'text', text: caption),
        ],
      ),
    );
  }
}
