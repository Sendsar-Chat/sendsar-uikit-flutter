import 'package:flutter/foundation.dart';
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

const locationPartType = 'data-location';

/// OpenStreetMap embed URL for [latitude] and [longitude].
String locationMapEmbedUrl(double latitude, double longitude) {
  const pad = 0.008;
  String n(double value) => value.toStringAsFixed(6);
  final minLon = longitude - pad;
  final minLat = latitude - pad;
  final maxLon = longitude + pad;
  final maxLat = latitude + pad;
  return 'https://www.openstreetmap.org/export/embed.html'
      '?bbox=${n(minLon)}%2C${n(minLat)}%2C${n(maxLon)}%2C${n(maxLat)}'
      '&layer=mapnik'
      '&marker=${n(latitude)}%2C${n(longitude)}';
}

/// Map app link for a shared pin. iOS opens Apple Maps. Other platforms open
/// Google Maps.
Uri nativeMapUri(
  double latitude,
  double longitude, {
  TargetPlatform? platform,
}) {
  final coords = '$latitude,$longitude';
  final target = platform ?? defaultTargetPlatform;
  if (target == TargetPlatform.iOS) {
    return Uri.https('maps.apple.com', '/', {
      'll': coords,
      'q': coords,
    });
  }
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': coords,
  });
}

/// HTML iframe that shows the map for [latitude] and [longitude].
String locationIframeMarkup(double latitude, double longitude) {
  final src = locationMapEmbedUrl(latitude, longitude);
  return '<iframe src="$src" width="100%" height="180" style="border:0" loading="lazy"></iframe>';
}

class SharedLocation {
  const SharedLocation({
    required this.latitude,
    required this.longitude,
    required this.embedUrl,
  });

  final double latitude;
  final double longitude;
  final String embedUrl;
}

SharedLocation? parseLocationPart(List<MessagePart> parts) {
  for (final part in parts) {
    if (part.type != locationPartType) continue;
    final data = part.data;
    if (data is! Map) continue;
    final latitude = _asDouble(data['latitude']);
    final longitude = _asDouble(data['longitude']);
    if (latitude == null || longitude == null) continue;
    final stored = data['embedUrl'];
    final embedUrl = stored is String && _isSafeMapEmbed(stored)
        ? stored
        : locationMapEmbedUrl(latitude, longitude);
    return SharedLocation(
      latitude: latitude,
      longitude: longitude,
      embedUrl: embedUrl,
    );
  }
  return null;
}

bool _isSafeMapEmbed(String url) {
  final uri = Uri.tryParse(url);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'www.openstreetmap.org' &&
      uri.path == '/export/embed.html';
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
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
  if (parseLocationPart(message.parts) != null) return 'Location';
  if (fileParts(message.parts).any(isAudioPart)) return 'Voice message';
  if (fileParts(message.parts).isNotEmpty) return 'Attachment';
  return message.previewText ?? '';
}
