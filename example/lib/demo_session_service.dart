import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sendsar_chat/sendsar_chat.dart';

import 'demo_environment.dart';

/// Calls the sample tenant backend (`sample-bff/`).
/// In your app, replace this with your own session endpoint.
class DemoSessionService {
  DemoSessionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SessionResponse> fetchSession(DemoUser identity) async {
    final res = await _client.post(
      Uri.parse('$bffBaseUrl/api/chat/session'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'chatUserId': identity.chatUserId,
        'displayName': identity.displayName,
        'seedUsers': demoUsers
            .map((u) => {
                  'chatUserId': u.chatUserId,
                  'displayName': u.displayName,
                })
            .toList(),
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw Exception(body?['error'] ?? 'Session failed: ${res.statusCode}');
    }

    return SessionResponse.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<String> ensureDirectMessage({
    required String selfId,
    required String peerId,
    String? peerName,
  }) async {
    final res = await _client.post(
      Uri.parse('$bffBaseUrl/api/chat/demo/ensure-dm'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'selfId': selfId,
        'peerId': peerId,
        'peerName': peerName,
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw Exception(body?['error'] ?? 'Ensure DM failed: ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['roomId'] as String;
  }

  Future<String> ensureGroup({
    required String selfId,
    required String name,
    required List<String> memberIds,
  }) async {
    final res = await _client.post(
      Uri.parse('$bffBaseUrl/api/chat/demo/ensure-group'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'selfId': selfId,
        'name': name,
        'memberIds': memberIds,
        'members': demoUsers
            .map((u) => {
                  'chatUserId': u.chatUserId,
                  'displayName': u.displayName,
                })
            .toList(),
      }),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw Exception(body?['error'] ?? 'Ensure group failed: ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return body['roomId'] as String;
  }
}
