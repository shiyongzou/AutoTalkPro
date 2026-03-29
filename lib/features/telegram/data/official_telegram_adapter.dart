import 'dart:async';

import '../../channel/domain/channel_adapter.dart';
import '../../channel/domain/channel_send_guard.dart';
import '../domain/telegram_adapter.dart';
import '../domain/telegram_config.dart';
import '../domain/telegram_official_auth_state.dart';
import 'tdlib_auth_gateway.dart';

/// 官方登录动作枚举（TDLib 骨架占位）。
enum TelegramOfficialLoginAction {
  connect,
  requestCode,
  verifyCode,
  logout,
  reconnect,
  recover,
}

/// 官方登录状态变更事件。
class TelegramOfficialAuthTransition {
  const TelegramOfficialAuthTransition({
    required this.action,
    required this.from,
    required this.to,
    this.error,
    required this.at,
  });

  final TelegramOfficialLoginAction action;
  final TelegramOfficialAuthState from;
  final TelegramOfficialAuthState to;
  final String? error;
  final DateTime at;
}

/// Telegram 官方接入骨架（TDLib 官方状态机）。
///
/// 提供可注入的 TDLib 抽象层与官方链路状态机：
/// 未登录 -> 待验证码 -> 已登录 / 错误，
/// 且支持错误或在线状态进入「重连中」辅助状态。
/// 当前默认 gateway 为模拟网关实现，后续可替换为真实 TDLib bridge。
class OfficialTelegramAdapter implements TelegramAdapter, ChannelSendGuard {
  OfficialTelegramAdapter({
    required this.config,
    TdLibAuthGateway? tdLibAuthGateway,
  }) : _tdLibAuthGateway = tdLibAuthGateway ?? const StubTdLibAuthGateway();

  final TelegramConfig config;
  final TdLibAuthGateway _tdLibAuthGateway;
  final StreamController<TelegramOfficialAuthTransition> _stateChanges =
      StreamController<TelegramOfficialAuthTransition>.broadcast();

  TelegramOfficialAuthState _authState = TelegramOfficialAuthState.loggedOut;
  String? _lastError;

  TelegramOfficialAuthState get authState => _authState;
  String? get lastError => _lastError;
  bool get isLoggedIn => _authState == TelegramOfficialAuthState.loggedIn;
  Stream<TelegramOfficialAuthTransition> get authStateChanges =>
      _stateChanges.stream;

  bool get canRequestCode => switch (_authState) {
    TelegramOfficialAuthState.loggedOut ||
    TelegramOfficialAuthState.waitingCode ||
    TelegramOfficialAuthState.error ||
    TelegramOfficialAuthState.reconnecting => true,
    TelegramOfficialAuthState.loggedIn => false,
  };

  bool get canSubmitCode => _authState == TelegramOfficialAuthState.waitingCode;
  bool get canLogout =>
      _authState != TelegramOfficialAuthState.loggedOut &&
      _authState != TelegramOfficialAuthState.reconnecting;
  bool get canReconnect => switch (_authState) {
    TelegramOfficialAuthState.loggedIn ||
    TelegramOfficialAuthState.error => true,
    TelegramOfficialAuthState.loggedOut ||
    TelegramOfficialAuthState.waitingCode ||
    TelegramOfficialAuthState.reconnecting => false,
  };

  String get nextStepHint => _authState.nextActionHint(lastError: _lastError);

  @override
  ChannelType get channelType => ChannelType.telegram;

  @override
  String get displayName => 'Telegram Official (TDLib State Machine)';

  /// 官方链路 connect 占位：真实 TDLib 接入后在此建立连接。
  Future<TelegramOfficialAuthState> connect() async {
    _transitionTo(
      action: TelegramOfficialLoginAction.connect,
      to: TelegramOfficialAuthState.loggedOut,
      error: null,
    );
    return _authState;
  }

  /// 统一接口：requestCode（别名）
  Future<TelegramOfficialAuthState> requestCode() => requestLoginCode();

  /// 统一接口：verifyCode（别名）
  Future<TelegramOfficialAuthState> verifyCode(String code) =>
      submitLoginCode(code);

  Future<TelegramOfficialAuthState> requestLoginCode() async {
    if (!canRequestCode) {
      _setStateError(
        '当前已登录，无需重复请求验证码',
        action: TelegramOfficialLoginAction.requestCode,
      );
      return _authState;
    }
    final result = await _tdLibAuthGateway.requestLoginCode(config: config);
    _applyAuthResult(TelegramOfficialLoginAction.requestCode, result);
    return _authState;
  }

  Future<TelegramOfficialAuthState> submitLoginCode(String code) async {
    if (!canSubmitCode) {
      _setStateError('请先请求验证码', action: TelegramOfficialLoginAction.verifyCode);
      return _authState;
    }
    final result = await _tdLibAuthGateway.submitLoginCode(
      config: config,
      code: code,
      currentState: _authState,
    );
    _applyAuthResult(TelegramOfficialLoginAction.verifyCode, result);
    return _authState;
  }

  Future<TelegramOfficialAuthState> logout() async {
    if (!canLogout) {
      if (_authState == TelegramOfficialAuthState.reconnecting) {
        _transitionTo(
          action: TelegramOfficialLoginAction.logout,
          to: _authState,
          error: '重连中不允许直接退出，请等待重连完成或稍后重试',
        );
      }
      return _authState;
    }
    final result = await _tdLibAuthGateway.logout(
      config: config,
      currentState: _authState,
    );
    _applyAuthResult(TelegramOfficialLoginAction.logout, result);
    return _authState;
  }

  Future<TelegramOfficialAuthState> reconnect() async {
    if (!canReconnect) return _authState;
    _transitionTo(
      action: TelegramOfficialLoginAction.reconnect,
      to: TelegramOfficialAuthState.reconnecting,
      error: null,
    );
    return _authState;
  }

  Future<TelegramOfficialAuthState> recoverFromError() async {
    if (_authState != TelegramOfficialAuthState.error) return _authState;
    _transitionTo(
      action: TelegramOfficialLoginAction.recover,
      to: TelegramOfficialAuthState.reconnecting,
      error: null,
    );
    return _authState;
  }

  void dispose() {
    _stateChanges.close();
  }

  void _setStateError(
    String message, {
    required TelegramOfficialLoginAction action,
  }) {
    _transitionTo(
      action: action,
      to: TelegramOfficialAuthState.error,
      error: message,
    );
  }

  void _applyAuthResult(
    TelegramOfficialLoginAction action,
    TdLibAuthResult result,
  ) {
    if (!_isTransitionAllowed(action: action, to: result.state)) {
      _setStateError('状态迁移非法：$action -> ${result.state.name}', action: action);
      return;
    }

    _transitionTo(
      action: action,
      to: result.state,
      error: result.state == TelegramOfficialAuthState.error
          ? (result.errorMessage ?? 'Telegram 官方链路异常')
          : null,
    );
  }

  void _transitionTo({
    required TelegramOfficialLoginAction action,
    required TelegramOfficialAuthState to,
    required String? error,
  }) {
    final from = _authState;
    _authState = to;
    _lastError = error;
    _stateChanges.add(
      TelegramOfficialAuthTransition(
        action: action,
        from: from,
        to: to,
        error: error,
        at: DateTime.now(),
      ),
    );
  }

  bool _isTransitionAllowed({
    required TelegramOfficialLoginAction action,
    required TelegramOfficialAuthState to,
  }) {
    switch (action) {
      case TelegramOfficialLoginAction.connect:
        return to == TelegramOfficialAuthState.loggedOut ||
            to == TelegramOfficialAuthState.error;
      case TelegramOfficialLoginAction.requestCode:
        return to == TelegramOfficialAuthState.waitingCode ||
            to == TelegramOfficialAuthState.error;
      case TelegramOfficialLoginAction.verifyCode:
        return to == TelegramOfficialAuthState.loggedIn ||
            to == TelegramOfficialAuthState.error;
      case TelegramOfficialLoginAction.logout:
        return to == TelegramOfficialAuthState.loggedOut ||
            to == TelegramOfficialAuthState.error ||
            to == TelegramOfficialAuthState.reconnecting;
      case TelegramOfficialLoginAction.reconnect:
      case TelegramOfficialLoginAction.recover:
        return to == TelegramOfficialAuthState.reconnecting ||
            to == TelegramOfficialAuthState.error;
    }
  }

  @override
  Future<ChannelSendGuardResult> checkBeforeSend({
    required String peerId,
    required String text,
  }) async {
    if (!config.useOfficial) {
      return ChannelSendGuardResult.block(
        '当前未启用 Telegram 官方接入，禁止发送',
        details: {'nextAction': '请启用 useOfficial 并完成官方登录链路配置'},
      );
    }
    if (!config.isValid) {
      return ChannelSendGuardResult.block(
        'Telegram 官方配置不完整，禁止发送',
        details: {'nextAction': '完善 apiId/apiHash/phoneNumber 后重试'},
      );
    }
    if (_authState == TelegramOfficialAuthState.loggedIn) {
      return ChannelSendGuardResult.allow(
        details: {
          'state': _authState.name,
          'stateLabel': _authState.label,
          'official': true,
          'nextAction': nextStepHint,
        },
      );
    }

    return ChannelSendGuardResult.block(
      _authState.guardBlockedReason(lastError: _lastError),
      details: {
        'state': _authState.name,
        'stateLabel': _authState.label,
        'nextAction': nextStepHint,
      },
    );
  }

  @override
  Future<List<TelegramChatSummary>> listChats() async {
    final now = DateTime.now();
    final preview = _authState.chatPreview(lastError: _lastError);

    return [
      ChannelChatSummary(
        channel: channelType,
        peerId: 'tg_official_tdlib_gateway',
        title: 'Telegram 官方接入（TDLib 状态机）',
        lastMessagePreview: preview,
        lastMessageAt: now.subtract(const Duration(minutes: 20)),
      ),
    ];
  }

  @override
  Future<bool> sendMessage({
    required String peerId,
    required String text,
  }) async {
    final guard = await checkBeforeSend(peerId: peerId, text: text);
    if (!guard.allowed) return false;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return peerId.trim().isNotEmpty && text.trim().isNotEmpty;
  }

  @override
  Future<ChannelHealthStatus> healthCheck() async {
    final issues = config.validate();
    return ChannelHealthStatus(
      channel: channelType,
      healthy: issues.isEmpty,
      message: issues.isEmpty
          ? 'Telegram 官方配置校验通过（${authState.label}）'
          : 'Telegram 配置不完整: ${issues.join('；')}',
      checkedAt: DateTime.now(),
      details: {
        'compliance': '仅支持 Telegram 官方 API / TDLib 路线',
        'gatewayMode': 'state_machine_simulation',
        'useOfficial': config.useOfficial,
        'authState': _authState.name,
        'authStateLabel': _authState.label,
        'nextAction': nextStepHint,
        if (_lastError != null) 'lastError': _lastError,
      },
    );
  }
}
