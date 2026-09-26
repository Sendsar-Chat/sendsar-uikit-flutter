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

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final segment in segments)
            switch (segment) {
              PlainTextSegment(:final value) => TextSpan(text: value),
              EmojiTextSegment(:final value) => WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: SendsarAnimatedEmoji(
                    emoji: value,
                    enabled: animatedEmoji,
                  ),
                ),
            },
        ],
      ),
    );
  }
}
