import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../utils/message_parts.dart';

/// Renders the OpenStreetMap iframe for a shared location.
class SendsarLocationMap extends StatefulWidget {
  const SendsarLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.interactive = false,
    this.onTap,
  });

  final double latitude;
  final double longitude;

  /// true: pan / pinch-zoom the map (full-screen viewer). false: static
  /// preview inside a chat bubble that forwards taps to [onTap].
  final bool interactive;
  final VoidCallback? onTap;

  @override
  State<SendsarLocationMap> createState() => _SendsarLocationMapState();
}

class _SendsarLocationMapState extends State<SendsarLocationMap> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFDBE4EE))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            final host = uri?.host ?? '';
            final allowed = uri != null &&
                (uri.scheme == 'about' ||
                    (uri.scheme == 'https' &&
                        (host.endsWith('openstreetmap.org') ||
                            host == 'unpkg.com')));
            return allowed
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadHtmlString(
        _mapDocument(widget.latitude, widget.longitude, widget.interactive),
        baseUrl: 'https://www.openstreetmap.org/',
      );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(
          controller: _controller,
          gestureRecognizers: widget.interactive
              ? {
                  Factory<OneSequenceGestureRecognizer>(
                    EagerGestureRecognizer.new,
                  ),
                }
              : const {},
        ),
        if (!widget.interactive)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
            ),
          ),
      ],
    );
  }
}

/// Opens a Telegram-style full-screen map for a shared location.
Future<void> showSendsarLocationViewer(
  BuildContext context, {
  required double latitude,
  required double longitude,
  String? subtitle,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => SendsarLocationViewer(
        latitude: latitude,
        longitude: longitude,
        subtitle: subtitle,
      ),
    ),
  );
}

class SendsarLocationViewer extends StatelessWidget {
  const SendsarLocationViewer({
    super.key,
    required this.latitude,
    required this.longitude,
    this.subtitle,
  });

  final double latitude;
  final double longitude;
  final String? subtitle;

  Future<void> _openNativeMap(BuildContext context) async {
    final uri = nativeMapUri(latitude, longitude);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the map app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final coords =
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFDBE4EE),
        body: Stack(
          fit: StackFit.expand,
          children: [
            SendsarLocationMap(
              latitude: latitude,
              longitude: longitude,
              interactive: true,
            ),
            Positioned(
              top: 0,
              left: 12,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _RoundButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    elevation: 6,
                    shadowColor: Colors.black38,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.location_on,
                                color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Location',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF111111),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle == null || subtitle!.isEmpty
                                      ? coords
                                      : '$subtitle · $coords',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF707579),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => _openNativeMap(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF3390EC),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text('Open in Maps'),
                          ),
                        ],
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black38,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: const Color(0xFF111111)),
      ),
    );
  }
}

String _mapDocument(double latitude, double longitude, bool interactive) {
  final flag = interactive ? 'true' : 'false';
  return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
  <style>
    html, body, #map { margin: 0; height: 100%; background: #dbe4ee; }
    .leaflet-control-attribution {
      font: 9px/1.4 -apple-system, Roboto, sans-serif;
      background: rgba(255,255,255,.7) !important;
      border-radius: 6px 0 0 0;
    }
    .pin { filter: drop-shadow(0 3px 3px rgba(0,0,0,.35)); }
  </style>
</head>
<body>
  <div id="map"></div>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script>
    var interactive = $flag;
    var map = L.map('map', {
      zoomControl: false,
      attributionControl: false,
      dragging: interactive,
      scrollWheelZoom: interactive,
      doubleClickZoom: interactive,
      touchZoom: interactive,
      boxZoom: false,
      keyboard: false,
      tap: false
    }).setView([$latitude, $longitude], interactive ? 16 : 15);
    L.control.attribution({prefix: false}).addAttribution('&copy; OpenStreetMap').addTo(map);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19
    }).addTo(map);
    var pin = L.divIcon({
      className: '',
      iconSize: [36, 46],
      iconAnchor: [18, 44],
      html: '<svg class="pin" width="36" height="46" viewBox="0 0 36 46" xmlns="http://www.w3.org/2000/svg">' +
            '<path d="M18 0C8.06 0 0 8.06 0 18c0 12.6 18 28 18 28s18-15.4 18-28C36 8.06 27.94 0 18 0z" fill="#E53935"/>' +
            '<circle cx="18" cy="18" r="7" fill="#fff"/></svg>'
    });
    L.marker([$latitude, $longitude], {icon: pin, interactive: false}).addTo(map);
  </script>
</body>
</html>
''';
}
