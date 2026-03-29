import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tg_ai_sales_desktop/features/wechatbot/application/wechat_message_listener.dart';

Future<void> _postJson({
  required Uri url,
  required Map<String, dynamic> body,
}) async {
  final client = HttpClient();
  final req = await client.postUrl(url);
  req.headers.set('Content-Type', 'application/json');
  req.add(utf8.encode(jsonEncode(body)));
  final resp = await req.close();
  expect(resp.statusCode, 200);
  await resp.drain();
  client.close(force: true);
}

void main() {
  group('WeChat listener flow', () {
    late WeChatMessageListener listener;

    setUp(() async {
      listener = WeChatMessageListener(callbackPort: 3902);
      await listener.start();
    });

    tearDown(() async {
      listener.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    test('private text message should be emitted', () async {
      final source = jsonEncode({
        'from': {
          'id': 'wx_u_1',
          'payload': {'name': 'Alice'},
        },
      });

      final future = listener.messages
          .firstWhere((m) => m.content == '你好')
          .timeout(const Duration(seconds: 3));

      await _postJson(
        url: Uri.parse(listener.callbackUrl),
        body: {
          'type': 'text',
          'content': '你好',
          'source': source,
          'isMentioned': 'false',
          'isMsgFromSelf': '0',
        },
      );

      final msg = await future;
      expect(msg.isText, true);
      expect(msg.isPrivate, true);
      // fromId now uses alias > name > id for wechatbot-webhook compatibility
      expect(msg.fromId, 'Alice');
      expect(msg.fromName, 'Alice');
      expect(msg.content, '你好');
    });

    test(
      'group @ message with true should be emitted and marked mentioned',
      () async {
        final source = jsonEncode({
          'from': {
            'id': 'wx_u_2',
            'payload': {'name': 'Bob'},
          },
          'room': {'id': '123@chatroom', 'topic': '测试群'},
        });

        final future = listener.messages
            .firstWhere((m) => m.content == '@机器人 在吗')
            .timeout(const Duration(seconds: 3));

        await _postJson(
          url: Uri.parse(listener.callbackUrl),
          body: {
            'type': 'text',
            'content': '@机器人 在吗',
            'source': source,
            'isMentioned': 'true',
            'isMsgFromSelf': '0',
          },
        );

        final msg = await future;
        expect(msg.isPrivate, false);
        expect(msg.isMentioned, true);
        expect(msg.roomId, '123@chatroom');
        expect(msg.roomName, '测试群');
      },
    );

    test('self message should be ignored', () async {
      final source = jsonEncode({
        'from': {
          'id': 'self',
          'payload': {'name': 'Self'},
        },
      });

      var emitted = false;
      final sub = listener.messages.listen((m) {
        if (m.content == '自己发的') {
          emitted = true;
        }
      });

      await _postJson(
        url: Uri.parse(listener.callbackUrl),
        body: {
          'type': 'text',
          'content': '自己发的',
          'source': source,
          'isMentioned': '0',
          'isMsgFromSelf': '1',
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 400));
      await sub.cancel();
      expect(emitted, false);
    });
  });
}
