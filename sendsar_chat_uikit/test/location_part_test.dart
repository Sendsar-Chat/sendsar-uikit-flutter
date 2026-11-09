import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendsar_chat/sendsar_chat.dart';
import 'package:sendsar_chat_uikit/sendsar_chat_uikit.dart';

void main() {
  test('location iframe uses the current coordinates', () {
    const latitude = 13.756300;
    const longitude = 100.501800;
    final embed = locationMapEmbedUrl(latitude, longitude);
    final iframe = locationIframeMarkup(latitude, longitude);

    expect(embed, contains('marker=13.756300%2C100.501800'));
    expect(embed, startsWith('https://www.openstreetmap.org/export/embed.html'));
    expect(iframe, startsWith('<iframe src="$embed"'));

    final parsed = parseLocationPart([
      MessagePart(
        type: locationPartType,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'embedUrl': embed,
          'iframe': iframe,
        },
      ),
    ]);
    expect(parsed?.latitude, latitude);
    expect(parsed?.longitude, longitude);
    expect(parsed?.embedUrl, embed);
  });

  test('location preview ignores an unsafe embed url', () {
    final parsed = parseLocationPart([
      MessagePart(
        type: locationPartType,
        data: {
          'latitude': 1,
          'longitude': 2,
          'embedUrl': 'https://evil.example/map',
          'iframe': '<iframe src="https://evil.example/map"></iframe>',
        },
      ),
    ]);
    expect(parsed?.embedUrl, locationMapEmbedUrl(1, 2));
  });

  test('tapping a map opens Google Maps on Android and Apple Maps on iOS', () {
    final android = nativeMapUri(
      13.7563,
      100.5018,
      platform: TargetPlatform.android,
    );
    final ios = nativeMapUri(
      13.7563,
      100.5018,
      platform: TargetPlatform.iOS,
    );

    expect(android.host, 'www.google.com');
    expect(android.path, '/maps/search/');
    expect(android.queryParameters['query'], '13.7563,100.5018');
    expect(ios.host, 'maps.apple.com');
    expect(ios.queryParameters['ll'], '13.7563,100.5018');
  });

  test('message preview labels a location share', () {
    final message = Message(
      id: 'm1',
      roomId: 'room',
      senderId: 'admin',
      parts: [
        MessagePart(
          type: locationPartType,
          data: {'latitude': 1.5, 'longitude': 2.5},
        ),
      ],
      previewText: null,
      createdAt: '2026-11-09T00:00:00Z',
    );
    expect(messagePreview(message), 'Location');
  });
}
