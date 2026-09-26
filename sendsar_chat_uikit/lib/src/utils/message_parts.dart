import 'package:flutter/material.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

String? filePartUrl(MessagePart part) {
  final url = part.accessUrl ?? part.url;
  if (url == null || url.isEmpty) return null;
  return url;
}

bool isFilePart(MessagePart part) {
  return part.type == 'file' &&
      (filePartUrl(part) != null ||
          (part.uploadId != null && part.uploadId!.isNotEmpty));
}

List<MessagePart> fileParts(List<MessagePart> parts) {
  return parts.where(isFilePart).toList();
}

/// Socket `messageUpdated` payloads often omit temporary `accessUrl`s.
/// Copy them from the previous local message so attachments stay visible.
Message preserveFileAccessUrls(Message updated, Message? previous) {
  if (previous == null) return updated;

  final previousByUploadId = <String, MessagePart>{};
  for (final part in previous.parts) {
    if (part.type == 'file' &&
        part.uploadId != null &&
        filePartUrl(part) != null) {
      previousByUploadId[part.uploadId!] = part;
    }
  }
  if (previousByUploadId.isEmpty) return updated;

  var changed = false;
  final parts = updated.parts.map((part) {
    if (part.type != 'file' ||
        filePartUrl(part) != null ||
        part.uploadId == null) {
      return part;
    }
    final prior = previousByUploadId[part.uploadId!];
    if (prior == null) return part;
    changed = true;
    return MessagePart(
      type: part.type,
      text: part.text,
      mediaType: part.mediaType,
      url: part.url ?? prior.url,
      uploadId: part.uploadId,
      filename: part.filename,
      accessUrl: part.accessUrl ?? prior.accessUrl,
      accessUrlExpiresAt: part.accessUrlExpiresAt ?? prior.accessUrlExpiresAt,
      data: part.data,
      state: part.state,
      extra: part.extra,
    );
  }).toList(growable: false);

  if (!changed) return updated;
  return Message(
    id: updated.id,
    roomId: updated.roomId,
    senderId: updated.senderId,
    clientMessageId: updated.clientMessageId,
    parts: parts,
    previewText: updated.previewText,
    createdAt: updated.createdAt,
    parentMessageId: updated.parentMessageId,
    parentMessage: updated.parentMessage,
    deletedAt: updated.deletedAt,
    deletedHidden: updated.deletedHidden,
    editedAt: updated.editedAt,
    pinnedAt: updated.pinnedAt,
    pinnedBy: updated.pinnedBy,
    forwardedFromId: updated.forwardedFromId,
    forwardedFromSenderId: updated.forwardedFromSenderId,
    reactions: updated.reactions,
  );
}

/// Keep pin/forward fields when SDK hydrate rebuilds a [Message].
Message mergeHydratedFileParts(Message original, Message hydrated) {
  return Message(
    id: original.id,
    roomId: original.roomId,
    senderId: original.senderId,
    clientMessageId: original.clientMessageId,
    parts: hydrated.parts,
    previewText: original.previewText,
    createdAt: original.createdAt,
    parentMessageId: original.parentMessageId,
    parentMessage: hydrated.parentMessage ?? original.parentMessage,
    deletedAt: original.deletedAt,
    deletedHidden: original.deletedHidden,
    editedAt: original.editedAt,
    pinnedAt: original.pinnedAt,
    pinnedBy: original.pinnedBy,
    forwardedFromId: original.forwardedFromId,
    forwardedFromSenderId: original.forwardedFromSenderId,
    reactions: original.reactions,
  );
}

bool messageNeedsFileHydration(Message message) {
  return message.parts.any(
    (part) =>
        part.type == 'file' &&
        part.uploadId != null &&
        part.uploadId!.isNotEmpty &&
        filePartUrl(part) == null,
  );
}

bool isImagePart(MessagePart part) {
  return isImageMediaType(part.mediaType, part.filename);
}

bool isAudioPart(MessagePart part) {
  final media = part.mediaType ?? '';
  if (media.startsWith('audio/')) return true;
  final filename = part.filename ?? '';
  return RegExp(r'^voice-message-', caseSensitive: false).hasMatch(filename) ||
      RegExp(r'\.(webm|m4a|mp3|ogg|wav|aac)(\?|$)', caseSensitive: false)
          .hasMatch(filename);
}

bool isImageMediaType(String? mediaType, [String? filename]) {
  final media = mediaType ?? '';
  if (media.startsWith('image/')) return true;
  final name = filename ?? '';
  return RegExp(r'\.(jpg|jpeg|png|gif|webp|bmp|svg)$', caseSensitive: false)
      .hasMatch(name);
}

({String name, String? previewUrl, String? mediaType}) filePreviewFromPart(
  MessagePart part,
) {
  return (
    name: part.filename ?? 'Download file',
    previewUrl: isImagePart(part) ? filePartUrl(part) : null,
    mediaType: part.mediaType ?? '',
  );
}

/// Material-style glyph for a non-image file attachment (parity with Angular).
IconData fileIconForAttachment(String name, [String mediaType = '']) {
  final lowerName = name.toLowerCase();
  final lowerMedia = mediaType.toLowerCase();

  if (lowerMedia.contains('pdf') || lowerName.endsWith('.pdf')) {
    return Icons.picture_as_pdf;
  }
  if (RegExp(r'\.(doc|docx)$').hasMatch(lowerName) ||
      lowerMedia.contains('word')) {
    return Icons.description;
  }
  if (RegExp(r'\.(xls|xlsx|csv)$').hasMatch(lowerName) ||
      lowerMedia.contains('spreadsheet') ||
      lowerMedia.contains('excel')) {
    return Icons.table_chart;
  }
  if (RegExp(r'\.(ppt|pptx)$').hasMatch(lowerName) ||
      lowerMedia.contains('presentation')) {
    return Icons.slideshow;
  }
  if (RegExp(r'\.(zip|rar|7z|tar|gz)$').hasMatch(lowerName) ||
      lowerMedia.contains('zip')) {
    return Icons.folder_zip;
  }
  if (lowerMedia.startsWith('video/') ||
      RegExp(r'\.(mp4|mov|avi|mkv|webm)$').hasMatch(lowerName)) {
    return Icons.videocam;
  }
  return Icons.insert_drive_file;
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
