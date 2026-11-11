import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../utils/message_parts.dart';

/// Renders the OpenStreetMap iframe for a shared location.
class SendsarLocationMap extends StatefulWidget {
  const SendsarLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

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
        _mapDocument(widget.latitude, widget.longitude),
        baseUrl: 'https://www.openstreetmap.org/',
      );
  }

  Future<void> _openNativeMap() async {
    final uri = nativeMapUri(widget.latitude, widget.longitude);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the map app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openNativeMap,
          ),
        ),
      ],
    );
  }
}

String _mapDocument(double latitude, double longitude) {
  return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css">
  <style>
    html, body, #map { margin: 0; height: 100%; background: #dbe4ee; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <script>
    var map = L.map('map', {
      zoomControl: false,
      dragging: false,
      scrollWheelZoom: false,
      doubleClickZoom: false,
      boxZoom: false,
      keyboard: false,
      tap: false,
      touchZoom: false
    }).setView([$latitude, $longitude], 15);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap'
    }).addTo(map);
    L.marker([$latitude, $longitude], {
      icon: L.icon({
        iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
        iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
        shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
        iconSize: [25, 41],
        iconAnchor: [12, 41],
        shadowSize: [41, 41]
      })
    }).addTo(map);
  </script>
</body>
</html>
''';
}
