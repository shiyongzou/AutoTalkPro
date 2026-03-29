import '../domain/telegram_config.dart';
import '../domain/telegram_official_auth_state.dart';

class TdLibAuthResult {
  const TdLibAuthResult({required this.state, this.errorMessage});

  final TelegramOfficialAuthState state;
  final String? errorMessage;
}

/// TDLib 官方登录链路抽象层。
///
/// 真实 TDLib 接入时应在此接口后挂接本地 bridge / native binding，
/// 当前默认实现仅用于状态流占位，不包含任何非官方或绕过方案。
abstract class TdLibAuthGateway {
  Future<TdLibAuthResult> requestLoginCode({required TelegramConfig config});

  Future<TdLibAuthResult> submitLoginCode({
    required TelegramConfig config,
    required String code,
    required TelegramOfficialAuthState currentState,
  });

  Future<TdLibAuthResult> logout({
    required TelegramConfig config,
    required TelegramOfficialAuthState currentState,
  });
}

class StubTdLibAuthGateway implements TdLibAuthGateway {
  const StubTdLibAuthGateway();

  @override
  Future<TdLibAuthResult> requestLoginCode({
    required TelegramConfig config,
  }) async {
    if (!config.isValid) {
      return const TdLibAuthResult(
        state: TelegramOfficialAuthState.error,
        errorMessage: 'Telegram 官方配置不完整，无法请求验证码',
      );
    }
    return const TdLibAuthResult(state: TelegramOfficialAuthState.waitingCode);
  }

  @override
  Future<TdLibAuthResult> submitLoginCode({
    required TelegramConfig config,
    required String code,
    required TelegramOfficialAuthState currentState,
  }) async {
    if (!config.isValid) {
      return const TdLibAuthResult(
        state: TelegramOfficialAuthState.error,
        errorMessage: 'Telegram 官方配置不完整，无法校验验证码',
      );
    }
    if (currentState != TelegramOfficialAuthState.waitingCode) {
      return const TdLibAuthResult(
        state: TelegramOfficialAuthState.error,
        errorMessage: '请先请求验证码',
      );
    }
    if (code.trim().isEmpty) {
      return const TdLibAuthResult(
        state: TelegramOfficialAuthState.error,
        errorMessage: '验证码不能为空',
      );
    }
    return const TdLibAuthResult(state: TelegramOfficialAuthState.loggedIn);
  }

  @override
  Future<TdLibAuthResult> logout({
    required TelegramConfig config,
    required TelegramOfficialAuthState currentState,
  }) async {
    return const TdLibAuthResult(state: TelegramOfficialAuthState.loggedOut);
  }
}
