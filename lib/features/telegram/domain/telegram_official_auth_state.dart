enum TelegramOfficialAuthState {
  loggedOut,
  waitingCode,
  loggedIn,
  error,
  reconnecting,
}

extension TelegramOfficialAuthStateLabel on TelegramOfficialAuthState {
  String get label {
    switch (this) {
      case TelegramOfficialAuthState.loggedOut:
        return '未登录';
      case TelegramOfficialAuthState.waitingCode:
        return '待验证码';
      case TelegramOfficialAuthState.loggedIn:
        return '已登录';
      case TelegramOfficialAuthState.error:
        return '错误';
      case TelegramOfficialAuthState.reconnecting:
        return '重连中';
    }
  }

  String nextActionHint({String? lastError}) {
    switch (this) {
      case TelegramOfficialAuthState.loggedOut:
        return '下一步：请求验证码并完成官方登录';
      case TelegramOfficialAuthState.waitingCode:
        return '下一步：输入验证码并提交校验';
      case TelegramOfficialAuthState.loggedIn:
        return '链路已就绪，可执行官方发送';
      case TelegramOfficialAuthState.error:
        return '链路异常：先进入重连，再请求验证码恢复';
      case TelegramOfficialAuthState.reconnecting:
        return '重连中：可重新请求验证码，完成会话恢复';
    }
  }

  String guardBlockedReason({String? lastError}) {
    switch (this) {
      case TelegramOfficialAuthState.loggedOut:
        return 'Telegram 官方通道未登录，禁止发送';
      case TelegramOfficialAuthState.waitingCode:
        return 'Telegram 官方通道待验证码，禁止发送';
      case TelegramOfficialAuthState.loggedIn:
        return 'Telegram 官方通道允许发送';
      case TelegramOfficialAuthState.error:
        return lastError ?? 'Telegram 官方通道状态错误，禁止发送';
      case TelegramOfficialAuthState.reconnecting:
        return 'Telegram 官方通道重连中，禁止发送';
    }
  }

  String chatPreview({String? lastError}) {
    switch (this) {
      case TelegramOfficialAuthState.loggedIn:
        return '官方链路可用（TDLib 状态机模拟网关）';
      case TelegramOfficialAuthState.waitingCode:
        return '已请求验证码，等待输入';
      case TelegramOfficialAuthState.loggedOut:
        return '未登录，请先请求验证码';
      case TelegramOfficialAuthState.error:
        return lastError ?? '状态错误，请先重连';
      case TelegramOfficialAuthState.reconnecting:
        return '会话重连中，请稍后请求验证码';
    }
  }
}
