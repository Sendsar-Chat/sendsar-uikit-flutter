import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;

/// Opens a Telegram-style full-screen photo viewer.
///
/// - Pinch or double-tap to zoom, drag to pan while zoomed.
/// - Swipe down (or up) to dismiss while not zoomed.
/// - Tap to hide / show the top bar.
/// - Hero transition from the in-chat thumbnail when [heroTag] matches the
///   tag used on the thumbnail.
Future<void> showSendsarImageViewer(
  BuildContext context, {
  required String url,
  String title = 'Photo',
  String? subtitle,
  Object? heroTag,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => SendsarImageViewer(
        url: url,
        title: title,
        subtitle: subtitle,
        heroTag: heroTag ?? url,
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class SendsarImageViewer extends StatefulWidget {
  const SendsarImageViewer({
    super.key,
    required this.url,
    this.title = 'Photo',
    this.subtitle,
    this.heroTag,
  });

  final String url;
  final String title;
  final String? subtitle;
  final Object? heroTag;

  @override
  State<SendsarImageViewer> createState() => _SendsarImageViewerState();
}

class _SendsarImageViewerState extends State<SendsarImageViewer>
    with SingleTickerProviderStateMixin {
  final _controller = TransformationController();
  late final AnimationController _zoomAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomTween;
  Offset _doubleTapAt = Offset.zero;

  bool _chromeVisible = true;
  bool _saving = false;
  String? _notice;

  double _dragDy = 0;
  Offset? _dragStart;
  bool _dragging = false;

  bool get _zoomed => _controller.value.getMaxScaleOnAxis() > 1.01;

  @override
  void initState() {
    super.initState();
    _zoomAnim.addListener(() {
      final tween = _zoomTween;
      if (tween != null) _controller.value = tween.value;
    });
  }

  @override
  void dispose() {
    _zoomAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final begin = _controller.value;
    final Matrix4 end;
    if (_zoomed) {
      end = Matrix4.identity();
    } else {
      const scale = 2.5;
      final p = _doubleTapAt;
      end = Matrix4.identity()
        ..translateByDouble(-p.dx * (scale - 1), -p.dy * (scale - 1), 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    }
    _zoomTween = Matrix4Tween(begin: begin, end: end).animate(
      CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOut),
    );
    _zoomAnim.forward(from: 0);
  }

  void _onInteractionStart(ScaleStartDetails d) {
    _dragStart = d.focalPoint;
    _dragging = false;
  }

  void _onInteractionUpdate(ScaleUpdateDetails d) {
    // Dismiss gesture: a single finger moving while the image is not zoomed.
    if (_zoomed || d.pointerCount != 1 || _dragStart == null) return;
    final dy = d.focalPoint.dy - _dragStart!.dy;
    if (!_dragging && dy.abs() < 6) return;
    setState(() {
      _dragging = true;
      _dragDy = dy;
    });
  }

  void _onInteractionEnd(ScaleEndDetails d) {
    if (!_dragging) return;
    final velocity = d.velocity.pixelsPerSecond.dy.abs();
    if (_dragDy.abs() > 110 || velocity > 900) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _dragging = false;
      _dragDy = 0;
    });
  }

  Future<void> _download() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _notice = null;
    });
    try {
      final access = await Gal.hasAccess();
      if (!access) {
        final granted = await Gal.requestAccess();
        if (!granted) throw StateError('Photo access was denied');
      }
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw StateError('Could not download the image');
      }
      await Gal.putImageBytes(
        response.bodyBytes,
        name: 'chat-${DateTime.now().millisecondsSinceEpoch}',
      );
      _flash('Saved to gallery');
    } catch (_) {
      _flash('Could not save image');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _flash(String text) {
    if (!mounted) return;
    setState(() => _notice = text);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted && _notice == text) setState(() => _notice = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fade = (1 - (_dragDy.abs() / (size.height * 0.5))).clamp(0.0, 1.0);
    final showChrome = _chromeVisible && !_dragging;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.5 + 0.5 * fade),
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _chromeVisible = !_chromeVisible),
              onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
              onDoubleTap: _onDoubleTap,
              child: Transform.translate(
                offset: Offset(0, _dragDy),
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: 5,
                  onInteractionStart: _onInteractionStart,
                  onInteractionUpdate: _onInteractionUpdate,
                  onInteractionEnd: _onInteractionEnd,
                  child: Center(
                    child: Hero(
                      tag: widget.heroTag ?? widget.url,
                      child: CachedNetworkImage(
                        imageUrl: widget.url,
                        fit: BoxFit.contain,
                        width: size.width,
                        height: size.height,
                        placeholder: (_, __) => const Center(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !showChrome,
                child: AnimatedOpacity(
                  opacity: showChrome ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: _TopBar(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    saving: _saving,
                    onBack: () => Navigator.of(context).maybePop(),
                    onDownload: _download,
                  ),
                ),
              ),
            ),
            if (_notice != null)
              Positioned(
                left: 24,
                right: 24,
                bottom: MediaQuery.paddingOf(context).bottom + 32,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xCC1C1C1E),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Text(
                        _notice!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.saving,
    required this.onBack,
    required this.onDownload,
  });

  final String title;
  final String? subtitle;
  final bool saving;
  final VoidCallback onBack;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 22),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Save to gallery',
                onPressed: saving ? null : onDownload,
                icon: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, color: Colors.white),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
