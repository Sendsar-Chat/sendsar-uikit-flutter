import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../utils/noto_emoji.dart';

/// Renders a Noto animated emoji when available, otherwise a Noto PNG.
///
/// Using PNG (instead of [Text]) avoids Flutter web CanvasKit warnings about
/// missing Noto fonts for emoji glyphs.
class SendsarAnimatedEmoji extends StatefulWidget {
  const SendsarAnimatedEmoji({
    super.key,
    required this.emoji,
    this.size = 22,
    this.enabled = true,
  });

  final String emoji;
  final double size;

  /// When true, prefer Noto Lottie animation when hosted for this emoji.
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
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: _useAnimation && widget.enabled
            ? ClipRect(
                child: Lottie.network(
                  notoLottieUrl(widget.emoji),
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  repeat: true,
                  errorBuilder: (_, __, ___) => _staticImage(),
                ),
              )
            : _staticImage(),
      ),
    );
  }

  Widget _staticImage() {
    final size = widget.size;
    return Image.network(
      notoEmojiPngUrl(widget.emoji, size: size.round()),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Text(
        widget.emoji,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size * 0.85,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
    );
  }
}
