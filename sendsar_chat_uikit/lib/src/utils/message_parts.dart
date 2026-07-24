import 'package:sendsar_chat/sendsar_chat.dart';

List<MessagePart> fileParts(List<MessagePart> parts) {
  return parts.where((p) => p.type == 'file' && p.url != null).toList();
}

bool isImagePart(MessagePart part) {
  final media = part.mediaType ?? '';
  return media.startsWith('image/');
}

String messagePreview(
  Message message, {
  String deletedPlaceholder = 'Message deleted',
  String? selfUserId,
}) {
  if (message.deletedHidden == true) return '';
  if (message.deletedAt != null) return deletedPlaceholder;
  final callLog = parseCallLogPart(message.parts);
  if (callLog != null) {
    return formatCallLogPreview(callLog, selfUserId);
  }
  final membership = parseMembershipPart(message.parts);
  if (membership != null) {
    return formatMembershipPreview(membership);
  }
  final text = textFromMessageParts(message.parts);
  if (text.isNotEmpty) return text;
  if (fileParts(message.parts).isNotEmpty) return 'Attachment';
  return message.previewText ?? '';
}
