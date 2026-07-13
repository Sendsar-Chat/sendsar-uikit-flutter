import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sendsar_chat_uikit/sendsar_chat_uikit.dart';

import 'demo_environment.dart';
import 'demo_session_service.dart';

void main() {
  runApp(const SendsarUIKitExampleApp());
}

class SendsarUIKitExampleApp extends StatefulWidget {
  const SendsarUIKitExampleApp({super.key});

  @override
  State<SendsarUIKitExampleApp> createState() => _SendsarUIKitExampleAppState();
}

class _SendsarUIKitExampleAppState extends State<SendsarUIKitExampleApp> {
  DemoUser? _identity;
  final _demo = DemoSessionService();
  final _shellKey = GlobalKey<SendsarChatShellState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sendsar UI Kit',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        extensions: const [SendsarChatTheme.light],
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        extensions: const [SendsarChatTheme.dark],
      ),
      home: _identity == null
          ? _IdentityPicker(
              onSelect: (user) => setState(() => _identity = user),
            )
          : SendsarScope(
              config: SendsarConfig(
                fetchSession: () => _demo.fetchSession(_identity!),
              ),
              child: Scaffold(
                appBar: AppBar(
                  title: Text('Chat as ${_identity!.displayName}'),
                  actions: [
                    TextButton(
                      onPressed: () => setState(() => _identity = null),
                      child: const Text('Switch user'),
                    ),
                  ],
                ),
                body: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _DemoActions(
                        selfId: _identity!.chatUserId,
                        demo: _demo,
                        onOpenRoom: (roomId, title) async {
                          await _shellKey.currentState?.openRoom(roomId, title: title);
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SendsarChatShell(
                          key: _shellKey,
                          users: demoUsers
                              .map(
                                (u) => UserDirectoryEntry(
                                  id: u.chatUserId,
                                  displayName: u.displayName,
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _IdentityPicker extends StatelessWidget {
  const _IdentityPicker({required this.onSelect});

  final ValueChanged<DemoUser> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sendsar UI Kit Demo')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Pick a demo user',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Run npm run setup and npm run start:bff first.\nBFF: $bffBaseUrl',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              for (final user in demoUsers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => onSelect(user),
                      child: Text(user.displayName),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoActions extends StatefulWidget {
  const _DemoActions({
    required this.selfId,
    required this.demo,
    required this.onOpenRoom,
  });

  final String selfId;
  final DemoSessionService demo;
  final Future<void> Function(String roomId, String? title) onOpenRoom;

  @override
  State<_DemoActions> createState() => _DemoActionsState();
}

class _DemoActionsState extends State<_DemoActions> {
  String? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (err) {
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peers = demoUsers.where((u) => u.chatUserId != widget.selfId).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final peer in peers)
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                          final roomId = await widget.demo.ensureDirectMessage(
                            selfId: widget.selfId,
                            peerId: peer.chatUserId,
                            peerName: peer.displayName,
                          );
                          await widget.onOpenRoom(roomId, peer.displayName);
                        }),
                child: Text('DM ${peer.displayName}'),
              ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final roomId = await widget.demo.ensureGroup(
                          selfId: widget.selfId,
                          name: 'Demo group',
                          memberIds: demoUsers.map((u) => u.chatUserId).toList(),
                        );
                        await widget.onOpenRoom(roomId, 'Demo group');
                      }),
              child: const Text('Create group'),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }
}
