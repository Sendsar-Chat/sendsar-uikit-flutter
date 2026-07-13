import 'package:flutter/material.dart';

import '../utils/emoji_segments.dart';
import 'sendsar_animated_emoji.dart';

/// Message body text with optional Noto animated emoji segments.
class SendsarMessageText extends StatelessWidget {
  const SendsarMessageText({
    super.key,
    required this.text,
    required this.style,
    this.animatedEmoji = true,
  });

  final String text;
  final TextStyle style;
  final bool animatedEmoji;

  @override
  Widget build(BuildContext context) {
    final segments = segmentTextWithEmoji(text);
    if (segments.length == 1 && segments.first is PlainTextSegment) {
      return Text(text, style: style);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final segment in segments)
          switch (segment) {
            PlainTextSegment(:final value) => Text(value, style: style),
            EmojiTextSegment(:final value) => SendsarAnimatedEmoji(
                emoji: value,
                enabled: animatedEmoji,
              ),
          },
      ],
    );
  }
}
