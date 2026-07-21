import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

import '../services/sendsar_call_service.dart';
import '../services/sendsar_session_service.dart';
import '../theme/sendsar_chat_theme.dart';
import '../theme/sendsar_styles.dart';
import '../utils/message_parts.dart';
import '../utils/room_label.dart';
import '../utils/user_directory.dart';
import 'sendsar_call_overlay.dart';
import 'sendsar_call_screen.dart';
import 'sendsar_composer.dart';
import 'sendsar_conversation_list.dart';
import 'sendsar_message_list.dart';
import 'sendsar_ongoing_call_bar.dart';
import 'sendsar_room_info.dart';

class SendsarChatShell extends StatefulWidget {
  const SendsarChatShell({
    super.key,
    required this.users,
    this.conversationListController,
    this.conversationListStyle,
    this.messageListStyle,
    this.conversationItemBuilder,
    this.messageBubbleBuilder,
  });

  final List<UserDirectoryEntry> users;
  final SendsarConversationListController? conversationListController;
  final SendsarConversationListStyle? conversationListStyle;
  final SendsarMessageListStyle? messageListStyle;
  final SendsarConversationItemBuilder? conversationItemBuilder;
  final SendsarMessageBubbleBuilder? messageBubbleBuilder;

  @override
  State<SendsarChatShell> createState() => SendsarChatShellState();
}

class SendsarChatShellState extends State<SendsarChatShell> {
  final _listController = SendsarConversationListController();
  RoomSummary? _selectedRoom;
  TypingByRoom _typingByRoom = {};
  Set<String> _onlineUserIds = {};
  bool _mobileShowThread = false;
  bool _showInfoPanel = true;
  bool _realtimeWired = false;
  TenantPresenceTracker? _presenceTracker;
  Timer? _reloadTimer;
  final List<void Function()> _unsubscribers = [];
  final Map<String, LastMessageOverride> _lastMessageOverrides = {};
  MaterialPageRoute<void>? _callRoute;
  bool _isNarrow = false;

  SendsarConversationListController get conversationListController =>
      widget.conversationListController ?? _listController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pollSessionReady());
  }

  @override
  void dispose() {
    for (final off in _unsubscribers) {
      off();
    }
    _presenceTracker?.destroy();
    _reloadTimer?.cancel();
    super.dispose();
  }

  void _pollSessionReady() {
    if (!mounted) return;
    final session = context.read<SendsarSessionService>();
    final timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      if (session.isReady && !_realtimeWired) {
        _wireRealtime(session);
      }
    });
    _unsubscribers.add(timer.cancel);
    session.addListener(() {
      if (session.isReady && !_realtimeWired) {
        _wireRealtime(session);
      }
    });
  }

  void _wireRealtime(SendsarSessionService session) {
    final client = session.client;
    if (client == null) return;
    _realtimeWired = true;

    _unsubscribers.add(
      client.on(SocketEvent.typing, (event) {
        if (event is! TypingEvent || !mounted) return;
        setState(() {
          _typingByRoom = applyTypingEvent(_typingByRoom, event);
        });
      }),
    );

    _unsubscribers.add(
      client.on(SocketEvent.newMessage, (msg) {
        if (msg is! Message || !mounted) return;
        _recordLastMessage(msg);
        _scheduleSidebarReload();
        final selected = _selectedRoom;
        if (selected != null && msg.roomId != selected.id) {
          unawaited(conversationListController.reload());
        }
      }),
    );

    _unsubscribers.add(
      client.on(SocketEvent.messageUpdated, (_) {
        if (!mounted) return;
        _scheduleSidebarReload();
      }),
    );

    _presenceTracker = createTenantPresenceTracker(client);
    _unsubscribers.add(
      _presenceTracker!.subscribe((ids) {
        if (!mounted) return;
        setState(() => _onlineUserIds = ids);
      }),
    );

    // Create the CallClient early so incoming call invites are received
    // before the user ever places a call.
    final calls = context.read<SendsarCallService>();
    calls.ensureReady();

    // Refresh the sidebar once a call finishes so the call-log message shows
    // up as the room's latest activity, and keep the full-screen call page
    // in sync with the call state on mobile.
    var wasInCall = calls.showCallUi;
    void onCallsChanged() {
      final inCall = calls.showCallUi;
      if (wasInCall && !inCall) {
        _scheduleSidebarReload();
      }
      wasInCall = inCall;
      _syncCallPage(calls);
    }

    calls.addListener(onCallsChanged);
    _unsubscribers.add(() => calls.removeListener(onCallsChanged));
  }

  /// On narrow (mobile) layouts the call UI is a pushed full-screen page,
  /// Telegram-style: open while the call is foregrounded, popped when it is
  /// minimized to the ongoing-call bar or ends.
  void _syncCallPage(SendsarCallService calls) {
    if (!mounted) return;
    final wantOpen = _isNarrow && calls.showCallUi && !calls.minimized;
    final route = _callRoute;

    if (wantOpen && route == null) {
      final newRoute = MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => SendsarCallScreen(
          title: _callOverlayTitle(calls),
          avatarUrl: _callOverlayAvatarUrl(calls),
          calls: calls,
        ),
      );
      _callRoute = newRoute;
      unawaited(
        Navigator.of(context, rootNavigator: true)
            .push(newRoute)
            .whenComplete(() {
          if (_callRoute == newRoute) _callRoute = null;
        }),
      );
      return;
    }

    if (!wantOpen && route != null) {
      _callRoute = null;
      if (route.isCurrent) {
        route.navigator?.pop();
      } else if (route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }
  }

  void _recordLastMessage(Message msg) {
    final selfUserId =
        context.read<SendsarSessionService>().session?.chatUserId;
    final preview = messagePreview(msg, selfUserId: selfUserId);
    if (preview.isEmpty) return;
    setState(() {
      _lastMessageOverrides[msg.roomId] =
          (preview: preview, createdAt: msg.createdAt);
    });
  }

  Future<void> _startCall(CallType type) async {
    final room = _selectedRoom;
    if (room == null) return;
    final calls = context.read<SendsarCallService>();
    if (calls.showCallUi) return;
    try {
      await calls.startCallOfType(room.id, type);
    } catch (_) {
      // Error surfaced in the call overlay via calls.error.
    }
  }

  void _onCallRedial(CallType type) {
    final calls = context.read<SendsarCallService>();
    if (calls.showCallUi) return;
    unawaited(_startCall(type));
  }

  String _callOverlayTitle(SendsarCallService calls) {
    final userMap = userDirectoryMap(widget.users);
    final invite = calls.incomingInvite;
    if (invite != null) {
      return displayNameFor(invite.createdByUserId, userMap);
    }

    final callRoomId = calls.activeCall?.roomId;
    final room = _selectedRoom;
    if (room != null && (callRoomId == null || callRoomId == room.id)) {
      return _roomTitle();
    }
    return 'Call';
  }

  String? _callOverlayAvatarUrl(SendsarCallService calls) {
    final userMap = userDirectoryMap(widget.users);
    final invite = calls.incomingInvite;
    if (invite != null) {
      return userMap[invite.createdByUserId]?.avatarUrl;
    }

    final room = _selectedRoom;
    final selfId =
        context.read<SendsarSessionService>().session?.chatUserId ?? '';
    if (room != null && isDirectMessage(room)) {
      final peerId = parseDmPeerId(room.externalId, selfId);
      if (peerId != null) return userMap[peerId]?.avatarUrl;
    }
    return null;
  }

  void _scheduleSidebarReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(const Duration(milliseconds: 800), () {
      unawaited(conversationListController.reload());
    });
  }

  void _onRoomSelect(RoomSummary room) {
    setState(() {
      _selectedRoom = room;
      _mobileShowThread = true;
      _showInfoPanel = true;
    });
  }

  Future<void> openRoom(String roomId, {String? title}) async {
    final session = context.read<SendsarSessionService>();
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (session.state.status == 'loading' &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!session.isReady) return;

    final room = await conversationListController.selectRoomById(roomId);
    if (!mounted) return;
    if (room != null) {
      setState(() {
        _selectedRoom = room;
        _mobileShowThread = true;
        _showInfoPanel = true;
      });
      return;
    }

    setState(() {
      _selectedRoom = RoomSummary(
        id: roomId,
        name: title?.trim().isNotEmpty == true ? title!.trim() : null,
        externalId: null,
        customType: 'demo_dm',
        metadata: null,
        isFrozen: false,
        lastMessage: null,
        createdAt: DateTime.now().toUtc().toIso8601String(),
      );
      _mobileShowThread = true;
      _showInfoPanel = true;
    });
    unawaited(conversationListController.reload());
  }

  String _roomTitle() {
    final room = _selectedRoom;
    final session = context.read<SendsarSessionService>();
    final selfId = session.session?.chatUserId ?? '';
    if (room == null) return 'Messages';
    return resolveRoomLabel(room, selfId, widget.users);
  }

  bool _roomIsGroup() {
    final room = _selectedRoom;
    return room != null && isGroupRoom(room);
  }

  String _typingLabel() {
    final room = _selectedRoom;
    final session = context.read<SendsarSessionService>();
    final selfId = session.session?.chatUserId ?? '';
    if (room == null || selfId.isEmpty) return '';

    final typingIds = otherTypingUserIds(_typingByRoom, room.id, selfId);
    final displayNames = {
      for (final u in widget.users) u.id: u.displayName,
    };
    return formatTypingLabel(
      typingIds,
      displayNames,
      directMessage: isDirectMessage(room),
    );
  }

  String _headerSubtitle() {
    final typing = _typingLabel();
    if (typing.isNotEmpty) return typing;

    final room = _selectedRoom;
    final session = context.read<SendsarSessionService>();
    final selfId = session.session?.chatUserId ?? '';
    if (room == null) return '';

    if (isGroupRoom(room)) {
      final members = widget.users.where((u) => u.id != selfId).toList();
      final memberCount = members.isEmpty ? 1 : members.length;
      final online = members.where((u) => _onlineUserIds.contains(u.id)).length;
      return '$memberCount members, $online online';
    }

    if (isDirectMessage(room)) {
      final peerId = parseDmPeerId(room.externalId, selfId);
      if (peerId != null && _onlineUserIds.contains(peerId)) {
        return 'Online';
      }
      return 'Direct message';
    }

    return 'Conversation';
  }

  void _openRoomInfo(BuildContext context, bool isNarrow) {
    final room = _selectedRoom;
    if (room == null) return;
    final selfUserId =
        context.read<SendsarSessionService>().session?.chatUserId ?? '';
    if (isNarrow) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.72,
          child: SendsarRoomInfo(
            room: room,
            users: widget.users,
            selfUserId: selfUserId,
            onlineUserIds: _onlineUserIds,
            title: _roomTitle(),
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      );
      return;
    }
    setState(() => _showInfoPanel = true);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SendsarSessionService>();
    final calls = context.watch<SendsarCallService>();
    final theme = context.sendsarTheme;
    final status = session.state.status;
    final selfUserId = session.session?.chatUserId ?? '';
    final selected = _selectedRoom;
    final width = MediaQuery.sizeOf(context).width;
    final isNarrow = width < 720;
    _isNarrow = isNarrow;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCallPage(calls));

    if (status == 'error') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(session.state.error ?? 'Connection failed'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => unawaited(session.restart()),
              child: const Text('Reconnect'),
            ),
          ],
        ),
      );
    }

    if (status == 'offline') {
      return const Center(child: Text('Chat is offline.'));
    }

    return DecoratedBox(
      decoration: theme.shellDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            if (isNarrow && calls.showCallUi && calls.minimized)
              SendsarOngoingCallBar(calls: calls),
            Expanded(
              child: Stack(
                children: [
                  if (status == 'loading')
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _ConnectingBar(theme: theme),
                    ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final showSidebar = !isNarrow || !_mobileShowThread;
                      final showThread = !isNarrow || _mobileShowThread;
                      final showInfo =
                          _showInfoPanel && (!isNarrow || _mobileShowThread);

                      return SizedBox(
                        height: constraints.maxHeight,
                        child: Row(
                          children: [
                            if (showSidebar)
                              SizedBox(
                                width: isNarrow ? constraints.maxWidth : 280,
                                child: SendsarConversationList(
                                  controller: conversationListController,
                                  selectedRoomId: selected?.id,
                                  users: widget.users,
                                  selfUserId: selfUserId,
                                  typingByRoom: _typingByRoom,
                                  onlineUserIds: _onlineUserIds,
                                  onRoomSelect: _onRoomSelect,
                                  style: widget.conversationListStyle,
                                  itemBuilder: widget.conversationItemBuilder,
                                  lastMessageOverrides: _lastMessageOverrides,
                                ),
                              ),
                            if (showSidebar && showThread)
                              VerticalDivider(width: 1, color: theme.border),
                            if (showThread)
                              Expanded(
                                child: selected == null
                                    ? const _ThreadEmpty()
                                    : Column(
                                        children: [
                                          _ThreadHeader(
                                            theme: theme,
                                            title: _roomTitle(),
                                            subtitle: _headerSubtitle(),
                                            typing: _typingLabel().isNotEmpty,
                                            showBack: isNarrow,
                                            onBack: () => setState(() =>
                                                _mobileShowThread = false),
                                            onInfo: () => _openRoomInfo(
                                                context, isNarrow),
                                            onAudioCall: calls.showCallUi
                                                ? null
                                                : () => unawaited(
                                                    _startCall('audio')),
                                            onVideoCall: calls.showCallUi
                                                ? null
                                                : () => unawaited(
                                                    _startCall('video')),
                                          ),
                                          Expanded(
                                            child: SendsarMessageList(
                                              roomId: selected.id,
                                              isGroup: _roomIsGroup(),
                                              users: widget.users,
                                              chatSettings:
                                                  session.session?.chatSettings,
                                              onActivity:
                                                  _scheduleSidebarReload,
                                              style: widget.messageListStyle,
                                              bubbleBuilder:
                                                  widget.messageBubbleBuilder,
                                              onCallRedial: _onCallRedial,
                                            ),
                                          ),
                                          SendsarComposer(
                                            roomId: selected.id,
                                            onSent: _scheduleSidebarReload,
                                          ),
                                        ],
                                      ),
                              ),
                            if (showInfo && selected != null && !isNarrow)
                              VerticalDivider(width: 1, color: theme.border),
                            if (showInfo && selected != null && !isNarrow)
                              SizedBox(
                                width: 260,
                                child: SendsarRoomInfo(
                                  room: selected,
                                  users: widget.users,
                                  selfUserId: selfUserId,
                                  onlineUserIds: _onlineUserIds,
                                  title: _roomTitle(),
                                  onClose: () =>
                                      setState(() => _showInfoPanel = false),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (calls.showCallUi && !isNarrow)
                    SendsarCallOverlay(
                      title: _callOverlayTitle(calls),
                      avatarUrl: _callOverlayAvatarUrl(calls),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectingBar extends StatelessWidget {
  const _ConnectingBar({required this.theme});

  final SendsarChatTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.connectingBg,
        border: Border(bottom: BorderSide(color: theme.connectingBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.accent,
            ),
          ),
          const SizedBox(width: 8),
          Text('Connecting to Sendsar…',
              style: TextStyle(color: theme.textSecondary)),
        ],
      ),
    );
  }
}

class _ThreadEmpty extends StatelessWidget {
  const _ThreadEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = context.sendsarTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Welcome to Sendsar', style: theme.titleStyle),
            const SizedBox(height: 8),
            Text(
              'Start a direct message or create a group to explore text, images, reactions, typing, and read receipts.',
              textAlign: TextAlign.center,
              style: theme.subtitleStyle,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.typing,
    required this.showBack,
    required this.onBack,
    required this.onInfo,
    this.onAudioCall,
    this.onVideoCall,
  });

  final SendsarChatTheme theme;
  final String title;
  final String subtitle;
  final bool typing;
  final bool showBack;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final VoidCallback? onAudioCall;
  final VoidCallback? onVideoCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showBack)
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          CircleAvatar(
            backgroundColor: theme.accentSoft,
            child: Text(
              initialsFor(title),
              style: TextStyle(
                color: theme.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
                  style: typing ? theme.typingStyle : theme.subtitleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: () {},
            icon: const Icon(Icons.search, size: 22),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Voice call',
            onPressed: onAudioCall,
            icon: const Icon(Icons.call, size: 22),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Video call',
            onPressed: onVideoCall,
            icon: const Icon(Icons.videocam, size: 22),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            onPressed: onInfo,
            icon: const Icon(Icons.more_vert, size: 22),
          ),
        ],
      ),
    );
  }
}
