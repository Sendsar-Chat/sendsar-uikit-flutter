import 'package:flutter/material.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

/// Optional overrides for [SendsarConversationList] appearance.
@immutable
class SendsarConversationListStyle {
  const SendsarConversationListStyle({
    this.headerTitle,
    this.searchHint,
    this.selectedColor,
    this.avatarRadius,
  });

  final String? headerTitle;
  final String? searchHint;
  final Color? selectedColor;
  final double? avatarRadius;
}

/// Optional overrides for [SendsarMessageList] appearance.
@immutable
class SendsarMessageListStyle {
  const SendsarMessageListStyle({
    this.bubbleRadius,
    this.selfBubbleColor,
    this.peerBubbleColor,
    this.imageHeight,
  });

  final double? bubbleRadius;
  final Color? selfBubbleColor;
  final Color? peerBubbleColor;
  final double? imageHeight;
}

/// Customize a conversation row while keeping default layout as fallback.
typedef SendsarConversationItemBuilder = Widget Function(
  BuildContext context,
  RoomSummary room,
  Widget defaultTile,
);

/// Customize a message bubble while keeping default layout as fallback.
typedef SendsarMessageBubbleBuilder = Widget Function(
  BuildContext context,
  Message message,
  bool isSelf,
  Widget defaultBubble,
);
