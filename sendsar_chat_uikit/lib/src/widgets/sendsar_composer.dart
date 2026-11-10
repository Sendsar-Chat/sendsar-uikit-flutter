import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:sendsar_chat/sendsar_chat.dart';
import 'package:uuid/uuid.dart';

import '../services/sendsar_chat_service.dart';
import '../services/sendsar_session_service.dart';
import '../theme/sendsar_chat_theme.dart';
import '../utils/emoji_groups.dart';
import '../utils/message_parts.dart';
import 'sendsar_animated_emoji.dart';
import 'sendsar_voice_message.dart';

const _toolSize = 40.0;
const _sendSize = 40.0;

class _PendingFile {
  const _PendingFile({
    required this.bytes,
    required this.name,
    required this.mediaType,
    this.durationSeconds,
  });

  final Uint8List bytes;
  final String name;
  final String mediaType;
  final int? durationSeconds;

  bool get isImage => isImageMediaType(mediaType, name);

  bool get isVoice =>
      mediaType.startsWith('audio/') ||
      name.toLowerCase().startsWith('voice-message-');
}

class SendsarComposer extends StatefulWidget {
  const SendsarComposer({
    super.key,
    required this.roomId,
    this.onSent,
    this.editingMessageId,
    this.editingText,
    this.editingImageUrl,
    this.editingFileParts = const [],
    this.onCancelEdit,
  });

  final String roomId;
  final VoidCallback? onSent;
  final String? editingMessageId;
  final String? editingText;
  final String? editingImageUrl;
  final List<MessagePart> editingFileParts;
  final VoidCallback? onCancelEdit;

  @override
  State<SendsarComposer> createState() => _SendsarComposerState();
}

class _SendsarComposerState extends State<SendsarComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  ComposerTypingController? _typingController;
  bool _sending = false;
  bool _recording = false;
  int _recordSeconds = 0;
  DateTime? _recordStarted;
  Timer? _recordTimer;
  Future<void>? _voiceStart;
  final _recorder = AudioRecorder();
  bool _showEmojiPicker = false;
  String? _error;
  _PendingFile? _pendingFile;
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
      _clearPendingFile();
      _bindTyping();
      if (_recording) unawaited(_finishVoice(send: false));
    }
    final startedEdit = widget.editingMessageId != null &&
        (widget.editingMessageId != oldWidget.editingMessageId ||
            widget.editingText != oldWidget.editingText);
    if (startedEdit) {
      _clearPendingFile();
      _controller.text = widget.editingText ?? '';
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else if (oldWidget.editingMessageId != null &&
        widget.editingMessageId == null) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    unawaited(_recorder.dispose());
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
    _typingController =
        ComposerTypingController(_ClientTypingAdapter(client), widget.roomId);
  }

  void _onTextChanged(String value) {
    _typingController?.onValueChange(value);
  }

  void _clearPendingFile() {
    _pendingFile = null;
  }

  bool get _showVoice =>
      !_sending &&
      widget.editingMessageId == null &&
      _controller.text.trim().isEmpty &&
      _pendingFile == null;

  void _holdVoice() {
    _voiceStart = _startVoice();
  }

  Future<void> _releaseVoice({required bool send}) async {
    await _voiceStart;
    await _finishVoice(send: send);
  }

  Future<void> _startVoice() async {
    if (_recording || _sending || widget.roomId.isEmpty) return;
    try {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        setState(() => _error = 'Microphone permission is required');
        return;
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice-message-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) {
        await _recorder.stop();
        return;
      }
      _recordTimer?.cancel();
      _recordStarted = DateTime.now();
      setState(() {
        _recording = true;
        _recordSeconds = 0;
        _error = null;
        _showEmojiPicker = false;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordSeconds++);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not start recording');
    }
  }

  Future<void> _finishVoice({required bool send}) async {
    _recordTimer?.cancel();
    _recordTimer = null;
    if (!await _recorder.isRecording()) {
      if (mounted && _recording) setState(() => _recording = false);
      return;
    }
    final path = await _recorder.stop();
    final started = _recordStarted;
    final held = started == null
        ? Duration.zero
        : DateTime.now().difference(started);
    if (mounted) {
      setState(() => _recording = false);
    }
    if (path == null) return;
    final file = File(path);
    if (!send || held < const Duration(milliseconds: 400) || !await file.exists()) {
      if (await file.exists()) await file.delete();
      return;
    }
    final bytes = await file.readAsBytes();
    await file.delete();
    if (bytes.isEmpty || !mounted) return;

    final seconds = (held.inMilliseconds / 1000).round().clamp(1, 86400);
    setState(() {
      _pendingFile = _PendingFile(
        bytes: bytes,
        name: 'voice-message-${DateTime.now().millisecondsSinceEpoch}.m4a',
        mediaType: 'audio/mp4',
        durationSeconds: seconds,
      );
      _error = null;
      _showEmojiPicker = false;
    });
    _focusNode.requestFocus();
  }

  bool get _canSend =>
      !_sending &&
      (_controller.text.trim().isNotEmpty ||
          _pendingFile != null ||
          (widget.editingMessageId != null &&
              widget.editingFileParts.isNotEmpty));

  Future<void> _submit() async {
    final body = _controller.text.trim();
    final pending = _pendingFile;
    final editingFiles = widget.editingMessageId != null;
    if ((body.isEmpty && pending == null &&
            !(editingFiles && widget.editingFileParts.isNotEmpty)) ||
        _sending) {
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });
    _typingController?.stop();

    try {
      final chat = context.read<SendsarChatService>();
      final clientMessageId = _uuid.v4();

      final editingId = widget.editingMessageId;
      if (editingId != null) {
        final parts = <MessagePart>[
          for (final part in widget.editingFileParts)
            MessagePart(
              type: 'file',
              mediaType: part.mediaType,
              uploadId: part.uploadId,
              url: part.url,
              filename: part.filename,
            ),
          if (body.isNotEmpty) MessagePart(type: 'text', text: body),
        ];
        if (parts.isEmpty) return;
        await chat.updateMessage(
          widget.roomId,
          editingId,
          UpdateMessageParams(parts: parts),
        );
      } else if (pending != null) {
        await chat.sendFileMessage(
          widget.roomId,
          bytes: pending.bytes,
          filename: pending.name,
          mediaType: pending.mediaType,
          text: body.isEmpty ? null : body,
          clientMessageId: clientMessageId,
        );
      } else {
        await chat.sendMessage(
          widget.roomId,
          SendMessageParams(
            parts: [MessagePart(type: 'text', text: body)],
            clientMessageId: clientMessageId,
          ),
        );
      }

      _controller.clear();
      setState(() {
        _showEmojiPicker = false;
        _clearPendingFile();
      });
      if (editingId != null) widget.onCancelEdit?.call();
      widget.onSent?.call();
    } catch (err) {
      setState(() {
        _error = err is Exception ? err.toString() : 'Failed to send';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _shareCurrentLocation() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _error = null;
      _showEmojiPicker = false;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw StateError('Turn on location services to share your position');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is required to share your position',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;

      final latitude = position.latitude;
      final longitude = position.longitude;
      await context.read<SendsarChatService>().sendMessage(
            widget.roomId,
            SendMessageParams(
              parts: [
                MessagePart(
                  type: locationPartType,
                  data: {
                    'latitude': latitude,
                    'longitude': longitude,
                    'embedUrl': locationMapEmbedUrl(latitude, longitude),
                    'iframe': locationIframeMarkup(latitude, longitude),
                  },
                ),
              ],
              clientMessageId: _uuid.v4(),
            ),
          );
      if (!mounted) return;
      widget.onSent?.call();
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err is StateError
            ? err.message
            : err is TimeoutException
                ? 'Could not find your current location'
                : 'Failed to share location';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickFile() async {
    if (_sending) return;
    setState(() {
      _showEmojiPicker = false;
      _error = null;
    });

    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.firstOrNull;
    if (file == null || file.bytes == null || !mounted) return;

    setState(() {
      _pendingFile = _PendingFile(
        bytes: Uint8List.fromList(file.bytes!),
        name: file.name,
        mediaType: file.extension != null
            ? _guessMediaType(file.extension!)
            : 'application/octet-stream',
      );
    });
  }

  String _guessMediaType(String ext) {
    final lower = ext.toLowerCase();
    const imageExts = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
    };
    return imageExts[lower] ?? 'application/octet-stream';
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
    final pending = _pendingFile;

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
                  if (pending != null && pending.isVoice)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 4, 0),
                      child: SendsarVoiceMessage(
                        key: ValueKey(pending.name),
                        bytes: pending.bytes,
                        mimeType: pending.mediaType,
                        durationSeconds: pending.durationSeconds,
                        recordedAt: '',
                        theme: theme,
                        outgoing: false,
                        onRemove: () {
                          if (_sending) return;
                          setState(_clearPendingFile);
                        },
                      ),
                    )
                  else if (pending != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                      child: _PendingFilePreview(
                        file: pending,
                        theme: theme,
                        disabled: _sending,
                        onRemove: () => setState(_clearPendingFile),
                      ),
                    ),
                  if (_showEmojiPicker)
                    SizedBox(
                      height: 160,
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          for (final group in defaultEmojiGroups) ...[
                            Text(group.label, style: theme.subtitleStyle),
                            Wrap(
                              spacing: 4,
                              children: [
                                for (final emoji in group.emojis)
                                  IconButton(
                                    onPressed: () => _insertEmoji(emoji),
                                    icon: SendsarAnimatedEmoji(
                                      emoji: emoji,
                                      size: 22,
                                      enabled: false,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                  if (widget.editingMessageId != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 2, 0),
                      child: Row(
                        children: [
                          if (widget.editingImageUrl != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: widget.editingImageUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Message',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.accent,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                                if ((widget.editingText ?? '').isNotEmpty)
                                  Text(
                                    widget.editingText!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.textPrimary,
                                      fontSize: 14,
                                      height: 1.2,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cancel edit',
                            visualDensity: VisualDensity.compact,
                            onPressed: _sending ? null : widget.onCancelEdit,
                            icon: Icon(Icons.close, size: 18, color: theme.textMuted),
                          ),
                        ],
                      ),
                    ),
                  if (_recording)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: Row(
                        children: [
                          Icon(Icons.fiber_manual_record, size: 12, color: theme.error),
                          const SizedBox(width: 6),
                          Text(
                            'Recording ${_recordSeconds ~/ 60}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: theme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!_recording)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 4,
                      minLines: 1,
                      enabled: !_sending,
                      textInputAction: TextInputAction.newline,
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        hintText: pending != null ? 'Add a caption…' : 'Message',
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
                          onPressed: _sending
                              ? null
                              : () => setState(
                                    () =>
                                        _showEmojiPicker = !_showEmojiPicker,
                                  ),
                          theme: theme,
                        ),
                        _ComposerToolButton(
                          icon: Icons.attach_file,
                          onPressed: _sending ? null : () => unawaited(_pickFile()),
                          theme: theme,
                        ),
                        _ComposerToolButton(
                          icon: Icons.location_on,
                          onPressed: _sending
                              ? null
                              : () => unawaited(_shareCurrentLocation()),
                          theme: theme,
                        ),
                        const Spacer(),
                        _SendButton(
                          size: _sendSize,
                          enabled: _canSend || _showVoice,
                          loading: _sending,
                          voice: _showVoice,
                          recording: _recording,
                          onPressed:
                              _canSend ? () => unawaited(_submit()) : null,
                          onVoiceStart:
                              _showVoice ? _holdVoice : null,
                          onVoiceEnd: _showVoice
                              ? () => unawaited(_releaseVoice(send: true))
                              : null,
                          onVoiceCancel: _showVoice
                              ? () => unawaited(_releaseVoice(send: false))
                              : null,
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

class _PendingFilePreview extends StatelessWidget {
  const _PendingFilePreview({
    required this.file,
    required this.theme,
    required this.onRemove,
    this.disabled = false,
  });

  final _PendingFile file;
  final SendsarChatTheme theme;
  final VoidCallback onRemove;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.sidebarBg,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Row(
          children: [
            if (file.isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(
                  file.bytes,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  fileIconForAttachment(file.name, file.mediaType),
                  size: 20,
                  color: theme.accent,
                ),
              ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: theme.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 28,
              height: 28,
              child: IconButton(
                onPressed: disabled ? null : onRemove,
                padding: EdgeInsets.zero,
                iconSize: 16,
                style: IconButton.styleFrom(
                  foregroundColor: theme.textMuted,
                ),
                tooltip: 'Remove attachment',
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
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

class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.size,
    required this.enabled,
    required this.loading,
    required this.theme,
    this.voice = false,
    this.recording = false,
    this.onPressed,
    this.onVoiceStart,
    this.onVoiceEnd,
    this.onVoiceCancel,
  });

  final double size;
  final bool enabled;
  final bool loading;
  final bool voice;
  final bool recording;
  final SendsarChatTheme theme;
  final VoidCallback? onPressed;
  final VoidCallback? onVoiceStart;
  final VoidCallback? onVoiceEnd;
  final VoidCallback? onVoiceCancel;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  void _start(LongPressStartDetails _) => widget.onVoiceStart?.call();

  void _end(LongPressEndDetails _) => widget.onVoiceEnd?.call();

  void _cancel() => widget.onVoiceCancel?.call();

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final voiceHold = widget.voice || widget.recording;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Material(
        color: widget.recording
            ? theme.error
            : widget.enabled
                ? theme.accent
                : theme.accent.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
        child: GestureDetector(
          onTap: widget.voice ? null : widget.onPressed,
          onLongPressStart: voiceHold ? _start : null,
          onLongPressEnd: voiceHold ? _end : null,
          onLongPressCancel: voiceHold ? _cancel : null,
          child: Center(
            child: widget.loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.bubbleSelfText,
                    ),
                  )
                : Icon(
                    widget.voice || widget.recording ? Icons.mic : Icons.send,
                    size: 20,
                    color: theme.bubbleSelfText,
                  ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

/// Bridges [SendsarClient] to the SDK's [ComposerTypingClient] interface.
class _ClientTypingAdapter implements ComposerTypingClient {
  _ClientTypingAdapter(this._client);

  final SendsarClient _client;

  @override
  bool get isConnected => _client.isConnected;

  @override
  void setTyping(TypingParams params) => _client.setTyping(params);
}
