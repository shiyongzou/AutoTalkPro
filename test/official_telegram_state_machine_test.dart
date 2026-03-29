import 'package:flutter_test/flutter_test.dart';

import 'package:tg_ai_sales_desktop/features/telegram/data/official_telegram_adapter.dart';
import 'package:tg_ai_sales_desktop/features/telegram/data/tdlib_auth_gateway.dart';
import 'package:tg_ai_sales_desktop/features/telegram/domain/telegram_config.dart';
import 'package:tg_ai_sales_desktop/features/telegram/domain/telegram_official_auth_state.dart';

void main() {
  test(
    'official telegram auth state machine follows placeholder flow',
    () async {
      final adapter = OfficialTelegramAdapter(
        config: const TelegramConfig(
          useOfficial: true,
          apiId: '10001',
          apiHash: 'hash',
          phoneNumber: '+85512345678',
          sessionPath: '/tmp/tdlib-session',
        ),
      );

      expect(adapter.authState, TelegramOfficialAuthState.loggedOut);

      await adapter.requestLoginCode();
      expect(adapter.authState, TelegramOfficialAuthState.waitingCode);

      await adapter.submitLoginCode('12345');
      expect(adapter.authState, TelegramOfficialAuthState.loggedIn);

      await adapter.logout();
      expect(adapter.authState, TelegramOfficialAuthState.loggedOut);
    },
  );

  test(
    'official telegram connect/requestCode/verifyCode/logout emits transitions',
    () async {
      final adapter = OfficialTelegramAdapter(
        config: const TelegramConfig(
          useOfficial: true,
          apiId: '10001',
          apiHash: 'hash',
          phoneNumber: '+85512345678',
        ),
      );

      final events = <TelegramOfficialAuthTransition>[];
      final sub = adapter.authStateChanges.listen(events.add);

      await adapter.connect();
      await adapter.requestCode();
      await adapter.verifyCode('246810');
      await adapter.logout();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final actions = events.map((e) => e.action).toList(growable: false);
      expect(actions, contains(TelegramOfficialLoginAction.requestCode));
      expect(actions, contains(TelegramOfficialLoginAction.verifyCode));
      expect(actions, contains(TelegramOfficialLoginAction.logout));

      final requestCodeEvents = events
          .where((e) => e.action == TelegramOfficialLoginAction.requestCode)
          .toList();
      final verifyCodeEvents = events
          .where((e) => e.action == TelegramOfficialLoginAction.verifyCode)
          .toList();
      final logoutEvents = events
          .where((e) => e.action == TelegramOfficialLoginAction.logout)
          .toList();

      expect(requestCodeEvents, isNotEmpty);
      expect(verifyCodeEvents, isNotEmpty);
      expect(logoutEvents, isNotEmpty);
      expect(requestCodeEvents.last.to, TelegramOfficialAuthState.waitingCode);
      expect(verifyCodeEvents.last.to, TelegramOfficialAuthState.loggedIn);
      expect(logoutEvents.last.to, TelegramOfficialAuthState.loggedOut);

      await sub.cancel();
      adapter.dispose();
    },
  );

  test('official telegram send is blocked before login', () async {
    final adapter = OfficialTelegramAdapter(
      config: const TelegramConfig(
        useOfficial: true,
        apiId: '10001',
        apiHash: 'hash',
        phoneNumber: '+85512345678',
      ),
    );

    final beforeLogin = await adapter.sendMessage(
      peerId: 'peer_1',
      text: 'hello',
    );
    expect(beforeLogin, isFalse);

    await adapter.requestLoginCode();
    await adapter.submitLoginCode('0000');

    final afterLogin = await adapter.sendMessage(
      peerId: 'peer_1',
      text: 'hello',
    );
    expect(afterLogin, isTrue);
  });

  test('official telegram guard blocks when useOfficial is disabled', () async {
    final adapter = OfficialTelegramAdapter(
      config: const TelegramConfig(
        useOfficial: false,
        apiId: '10001',
        apiHash: 'hash',
        phoneNumber: '+85512345678',
      ),
    );

    final guard = await adapter.checkBeforeSend(
      peerId: 'peer_1',
      text: 'hello',
    );

    expect(guard.allowed, isFalse);
    expect(guard.reason, contains('未启用 Telegram 官方接入'));
    expect(guard.details['nextAction'], contains('启用 useOfficial'));
  });

  test(
    'official telegram guard nextAction stays consistent with state hint',
    () async {
      final adapter = OfficialTelegramAdapter(
        config: const TelegramConfig(
          useOfficial: true,
          apiId: '10001',
          apiHash: 'hash',
          phoneNumber: '+85512345678',
        ),
      );

      final loggedOutGuard = await adapter.checkBeforeSend(
        peerId: 'peer_1',
        text: 'hello',
      );
      expect(loggedOutGuard.details['nextAction'], adapter.nextStepHint);

      await adapter.requestLoginCode();
      final waitingGuard = await adapter.checkBeforeSend(
        peerId: 'peer_1',
        text: 'hello',
      );
      expect(waitingGuard.details['nextAction'], adapter.nextStepHint);
    },
  );

  test('official telegram enters error state on invalid code flow', () async {
    final adapter = OfficialTelegramAdapter(
      config: const TelegramConfig(
        useOfficial: true,
        apiId: '10001',
        apiHash: 'hash',
        phoneNumber: '+85512345678',
      ),
    );

    await adapter.submitLoginCode('123456');

    expect(adapter.authState, TelegramOfficialAuthState.error);
    expect(adapter.lastError, contains('请先请求验证码'));

    await adapter.recoverFromError();
    expect(adapter.authState, TelegramOfficialAuthState.reconnecting);

    await adapter.requestLoginCode();
    expect(adapter.authState, TelegramOfficialAuthState.waitingCode);
  });

  test('official telegram blocks illegal transition after login', () async {
    final adapter = OfficialTelegramAdapter(
      config: const TelegramConfig(
        useOfficial: true,
        apiId: '10001',
        apiHash: 'hash',
        phoneNumber: '+85512345678',
      ),
      tdLibAuthGateway: _BadTransitionGateway(),
    );

    await adapter.requestLoginCode();
    await adapter.submitLoginCode('123456');

    expect(adapter.authState, TelegramOfficialAuthState.error);
    expect(adapter.lastError, contains('状态迁移非法'));
  });

  test(
    'official telegram enters reconnecting and blocks send until relogin',
    () async {
      final adapter = OfficialTelegramAdapter(
        config: const TelegramConfig(
          useOfficial: true,
          apiId: '10001',
          apiHash: 'hash',
          phoneNumber: '+85512345678',
        ),
      );

      await adapter.requestLoginCode();
      await adapter.submitLoginCode('246810');
      expect(adapter.authState, TelegramOfficialAuthState.loggedIn);

      await adapter.reconnect();
      expect(adapter.authState, TelegramOfficialAuthState.reconnecting);

      final sendWhileReconnecting = await adapter.checkBeforeSend(
        peerId: 'peer_1',
        text: 'ping',
      );
      expect(sendWhileReconnecting.allowed, isFalse);
      expect(sendWhileReconnecting.reason, contains('重连中'));

      await adapter.requestLoginCode();
      await adapter.submitLoginCode('246810');
      expect(adapter.authState, TelegramOfficialAuthState.loggedIn);
    },
  );

  test('official telegram adapter supports injectable tdlib gateway', () async {
    final fakeGateway = _FakeTdLibAuthGateway();
    final adapter = OfficialTelegramAdapter(
      config: const TelegramConfig(
        useOfficial: true,
        apiId: '10001',
        apiHash: 'hash',
        phoneNumber: '+85512345678',
      ),
      tdLibAuthGateway: fakeGateway,
    );

    await adapter.requestLoginCode();
    expect(adapter.authState, TelegramOfficialAuthState.waitingCode);

    await adapter.submitLoginCode('246810');
    expect(adapter.authState, TelegramOfficialAuthState.loggedIn);

    await adapter.logout();
    expect(adapter.authState, TelegramOfficialAuthState.loggedOut);

    expect(fakeGateway.calls, [
      'requestLoginCode',
      'submitLoginCode',
      'logout',
    ]);
  });

  test('official telegram does not allow logout during reconnecting', () async {
    final adapter = OfficialTelegramAdapter(
      config: const TelegramConfig(
        useOfficial: true,
        apiId: '10001',
        apiHash: 'hash',
        phoneNumber: '+85512345678',
      ),
    );

    await adapter.requestLoginCode();
    await adapter.submitLoginCode('246810');
    await adapter.reconnect();

    final stateAfterLogout = await adapter.logout();

    expect(stateAfterLogout, TelegramOfficialAuthState.reconnecting);
    expect(adapter.authState, TelegramOfficialAuthState.reconnecting);
    expect(adapter.lastError, contains('重连中不允许直接退出'));
  });
}

class _BadTransitionGateway implements TdLibAuthGateway {
  @override
  Future<TdLibAuthResult> requestLoginCode({
    required TelegramConfig config,
  }) async {
    return const TdLibAuthResult(state: TelegramOfficialAuthState.waitingCode);
  }

  @override
  Future<TdLibAuthResult> submitLoginCode({
    required TelegramConfig config,
    required String code,
    required TelegramOfficialAuthState currentState,
  }) async {
    return const TdLibAuthResult(state: TelegramOfficialAuthState.waitingCode);
  }

  @override
  Future<TdLibAuthResult> logout({
    required TelegramConfig config,
    required TelegramOfficialAuthState currentState,
  }) async {
    return const TdLibAuthResult(state: TelegramOfficialAuthState.loggedOut);
  }
}

class _FakeTdLibAuthGateway implements TdLibAuthGateway {
  final List<String> calls = [];

  @override
  Future<TdLibAuthResult> requestLoginCode({
    required TelegramConfig config,
  }) async {
    calls.add('requestLoginCode');
    return const TdLibAuthResult(state: TelegramOfficialAuthState.waitingCode);
  }

  @override
  Future<TdLibAuthResult> submitLoginCode({
    required TelegramConfig config,
    required String code,
    required TelegramOfficialAuthState currentState,
  }) async {
    calls.add('submitLoginCode');
    expect(currentState, TelegramOfficialAuthState.waitingCode);
    expect(code, '246810');
    return const TdLibAuthResult(state: TelegramOfficialAuthState.loggedIn);
  }

  @override
  Future<TdLibAuthResult> logout({
    required TelegramConfig config,
    required TelegramOfficialAuthState currentState,
  }) async {
    calls.add('logout');
    expect(currentState, TelegramOfficialAuthState.loggedIn);
    return const TdLibAuthResult(state: TelegramOfficialAuthState.loggedOut);
  }
}
