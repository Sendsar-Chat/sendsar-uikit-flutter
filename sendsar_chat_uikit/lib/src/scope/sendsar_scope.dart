import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../config/sendsar_config.dart';
import '../services/sendsar_call_service.dart';
import '../services/sendsar_chat_service.dart';
import '../services/sendsar_session_service.dart';
import '../theme/sendsar_chat_theme.dart';

/// Registers Sendsar session + chat services for your Flutter app.
class SendsarScope extends StatefulWidget {
  const SendsarScope({
    super.key,
    required this.config,
    required this.child,
    this.autoStart = true,
    this.theme,
  });

  final SendsarConfig config;
  final Widget child;
  final bool autoStart;

  /// Override light/dark chat tokens. Defaults follow [Theme.of] brightness.
  final SendsarChatTheme? theme;

  @override
  State<SendsarScope> createState() => _SendsarScopeState();
}

class _SendsarScopeState extends State<SendsarScope> {
  late final SendsarSessionService _sessionService;
  late final SendsarChatService _chatService;
  late final SendsarCallService _callService;

  @override
  void initState() {
    super.initState();
    _sessionService = SendsarSessionService(widget.config);
    _chatService = SendsarChatService(_sessionService);
    _callService = SendsarCallService(_sessionService);
    if (widget.autoStart) {
      _sessionService.start();
    }
  }

  @override
  void dispose() {
    _callService.dispose();
    _sessionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SendsarConfig>.value(value: widget.config),
        ChangeNotifierProvider<SendsarSessionService>.value(
          value: _sessionService,
        ),
        Provider<SendsarChatService>.value(value: _chatService),
        ChangeNotifierProvider<SendsarCallService>.value(value: _callService),
      ],
      child: widget.theme == null
          ? widget.child
          : SendsarThemeOverride(
              theme: widget.theme!,
              child: widget.child,
            ),
    );
  }
}

List<SingleChildWidget> sendsarProviders({
  required SendsarConfig config,
  required SendsarSessionService sessionService,
  required SendsarChatService chatService,
  SendsarCallService? callService,
}) {
  return [
    Provider<SendsarConfig>.value(value: config),
    ChangeNotifierProvider<SendsarSessionService>.value(value: sessionService),
    Provider<SendsarChatService>.value(value: chatService),
    if (callService != null)
      ChangeNotifierProvider<SendsarCallService>.value(value: callService),
  ];
}
