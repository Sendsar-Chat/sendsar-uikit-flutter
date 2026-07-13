import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sendsar_chat/sendsar_chat.dart';
import 'package:uuid/uuid.dart';

import '../services/sendsar_chat_service.dart';
import '../services/sendsar_session_service.dart';
import '../theme/sendsar_chat_theme.dart';
import '../utils/composer_typing_controller.dart';

const _emojiGroups = [
  (
    label: 'Popular',
    emojis: ['👍', '❤️', '😂', '🔥', '🙏', '👏', '😭', '😍', '🎉', '😊', '✨', '🤔'],
  ),
  (
    label: 'Smileys',
    emojis: ['😀', '😁', '😂', '🤣', '😊', '😍', '😘', '😎', '🥳', '😭', '😡', '🤔'],
  ),
];

const _toolSize = 40.0;
const _sendSize = 40.0;

class SendsarComposer extends StatefulWidget {
  const SendsarComposer({
    super.key,
    required this.roomId,
    this.onSent,
  });

  final String roomId;
  final VoidCallback? onSent;

  @override
  State<SendsarComposer> createState() => _SendsarComposerState();
}

class _SendsarComposerState extends State<SendsarComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  ComposerTypingController? _typingController;
  bool _sending = false;
  bool _showEmojiPicker = false;
  String? _error;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _bindTyping();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant SendsarComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomId != widget.roomId) {
      _showEmojiPicker = false;
      _bindTyping();
    }
  }

  @override
  void dispose() {
    _typingController?.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _bindTyping() {
    _typingController?.dispose();
    final client = context.read<SendsarSessionService>().client;
    if (client == null || widget.roomId.isEmpty) {
      _typingController = null;
      return;
    }
    _typingController = ComposerTypingController(client, widget.roomId);
  }

  void _onTextChanged(String value) {
    _typingController?.onValueChange(value);
  }

  bool get _canSend => _controller.text.trim().isNotEmpty && !_sending;

  Future<void> _submit() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    _typingController?.stop();

    try {
      final chat = context.read<SendsarChatService>();
      await chat.sendMessage(
        widget.roomId,
        SendMessageParams(
          parts: [MessagePart(type: 'text', text: body)],
          clientMessageId: _uuid.v4(),
        ),
      );
      _controller.clear();
      setState(() => _showEmojiPicker = false);
      widget.onSent?.call();
    } catch (err) {
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to send';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickFile() async {
    if (_sending) return;
    setState(() => _showEmojiPicker = false);

    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    _typingController?.stop();

    try {
      final chat = context.read<SendsarChatService>();
      await chat.sendFileMessage(
        widget.roomId,
        bytes: file.bytes!,
        filename: file.name,
        mediaType: file.extension != null
            ? _guessMediaType(file.extension!)
            : 'application/octet-stream',
        clientMessageId: _uuid.v4(),
      );
      widget.onSent?.call();
    } catch (err) {
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to send file';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _guessMediaType(String ext) {
    final lower = ext.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(lower)) {
      return 'image/$lower';
    }
    return 'application/octet-stream';
  }

  void _insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final next = '${text.substring(0, start)}$emoji${text.substring(end)}';
    _controller.text = next;
    _controller.selection = TextSelection.collapsed(offset: start + emoji.length);
    _onTextChanged(next);
    setState(() => _showEmojiPicker = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    return Material(
      color: theme.sidebarBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(_error!, style: TextStyle(color: theme.error)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.surface,
                border: Border.all(color: theme.accent, width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showEmojiPicker)
                    SizedBox(
                      height: 160,
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          for (final group in _emojiGroups) ...[
                            Text(group.label, style: theme.subtitleStyle),
                            Wrap(
                              spacing: 4,
                              children: [
                                for (final emoji in group.emojis)
                                  IconButton(
                                    onPressed: () => _insertEmoji(emoji),
                                    icon: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      onChanged: _onTextChanged,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 6, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ComposerToolButton(
                          icon: Icons.emoji_emotions_outlined,
                          active: _showEmojiPicker,
                          onPressed: () =>
                              setState(() => _showEmojiPicker = !_showEmojiPicker),
                          theme: theme,
                        ),
                        _ComposerToolButton(
                          icon: Icons.attach_file,
                          onPressed: _sending ? null : _pickFile,
                          theme: theme,
                        ),
                        const Spacer(),
                        _SendButton(
                          size: _sendSize,
                          enabled: _canSend,
                          loading: _sending,
                          onPressed: _canSend ? () => unawaited(_submit()) : null,
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerToolButton extends StatelessWidget {
  const _ComposerToolButton({
    required this.icon,
    required this.theme,
    this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final SendsarChatTheme theme;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _toolSize,
      height: _toolSize,
      child: IconButton(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        iconSize: 22,
        style: IconButton.styleFrom(
          foregroundColor: active ? theme.accent : theme.textSecondary,
          backgroundColor: active ? theme.accentSoft : Colors.transparent,
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.size,
    required this.enabled,
    required this.loading,
    required this.theme,
    this.onPressed,
  });

  final double size;
  final bool enabled;
  final bool loading;
  final SendsarChatTheme theme;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: enabled ? theme.accent : theme.accent.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.bubbleSelfText,
                    ),
                  )
                : Icon(Icons.send, size: 20, color: theme.bubbleSelfText),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
