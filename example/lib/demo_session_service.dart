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
}
