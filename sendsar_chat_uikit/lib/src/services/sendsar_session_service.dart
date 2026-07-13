import 'package:flutter/foundation.dart';
import 'package:sendsar_chat/sendsar_chat.dart';

import '../config/sendsar_config.dart';

class SendsarSessionService extends ChangeNotifier {
  SendsarSessionService(this._config) {
    _manager = createSessionManager(
      CreateSessionManagerOptions(
        fetchSession: _config.fetchSession,
        refreshBeforeExpiryMs:
            _config.refreshBeforeExpiryMs ?? defaultRefreshBeforeExpiryMs,
        onStateChange: _onStateChange,
      ),
    );
    _state = _manager.getState();
  }

  final SendsarConfig _config;
  late final SessionManager _manager;
  late SessionManagerState _state;

  SessionManagerState get state => _state;

  SendsarClient? get client => _state.client;

  SessionResponse? get session => _state.session;

  bool get isReady => _state.status == 'ready';

  Future<void> start() => _manager.start();

  Future<void> stop() => _manager.stop();

  Future<void> restart() => _manager.restart();

  @override
  void dispose() {
    _manager.stop();
    super.dispose();
  }

  void _onStateChange(SessionManagerState next) {
    _state = next;
    notifyListeners();
  }
}
