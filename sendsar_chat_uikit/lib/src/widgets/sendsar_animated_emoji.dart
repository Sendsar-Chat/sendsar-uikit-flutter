import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../utils/noto_emoji.dart';

/// Renders a Noto animated emoji when available, otherwise static text.
class SendsarAnimatedEmoji extends StatefulWidget {
  const SendsarAnimatedEmoji({
    super.key,
    required this.emoji,
    this.size = 22,
    this.enabled = true,
  });

  final String emoji;
  final double size;
  final bool enabled;

  @override
  State<SendsarAnimatedEmoji> createState() => _SendsarAnimatedEmojiState();
}

class _SendsarAnimatedEmojiState extends State<SendsarAnimatedEmoji> {
  bool _useAnimation = false;

  @override
  void initState() {
    super.initState();
    _resolveAnimation();
  }

  @override
  void didUpdateWidget(covariant SendsarAnimatedEmoji oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emoji != widget.emoji ||
        oldWidget.enabled != widget.enabled) {
      _resolveAnimation();
    }
  }

  Future<void> _resolveAnimation() async {
    if (!widget.enabled) {
      if (mounted) setState(() => _useAnimation = false);
      return;
    }
    setState(() => _useAnimation = false);
    final emoji = widget.emoji;
    final available = await hasNotoAnimation(emoji);
    if (!mounted || widget.emoji != emoji) return;
    if (available) setState(() => _useAnimation = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_useAnimation && widget.enabled) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Lottie.network(
          notoLottieUrl(widget.emoji),
          fit: BoxFit.contain,
          repeat: true,
          errorBuilder: (_, __, ___) => _static(),
        ),
      );
    }
    return _static();
  }

  Widget _static() {
    return Text(
      widget.emoji,
      style: TextStyle(fontSize: widget.size * 0.85, height: 1),
    );
  }
}
