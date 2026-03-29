import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/logging/support_logger.dart';
import '../../channel/domain/channel_adapter.dart';
import '../../channel/domain/channel_send_guard.dart';
import '../domain/wecom_config.dart';

/// 企业微信官方API适配器
///
/// 对接 qyapi.weixin.qq.com 官方接口:
/// - 获取access_token: GET /cgi-bin/gettoken?corpid=&corpsecret=
/// - 发送应用消息: POST /cgi-bin/message/send?access_token=
/// - 获取外部联系人列表: GET /cgi-bin/externalcontact/list?access_token=&userid=
class WeComAdapter implements ChannelAdapter, ChannelSendGuard {
  WeComAdapter({required this.config, http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final WeComConfig config;
  final http.Client _client;

  // access_token 缓存
  String? _accessToken;
  DateTime? _tokenExpiresAt;

  @override
  ChannelType get channelType => ChannelType.wecom;

  @override
  String get displayName => '企业微信';

  /// 获取或刷新 access_token
  Future<String?> _getAccessToken() async {
    // 缓存有效则直接返回
    if (_accessToken != null &&
        _tokenExpiresAt != null &&
        DateTime.now().isBefore(_tokenExpiresAt!)) {
      return _accessToken;
    }

    if (!config.isValid) return null;

    try {
      final url = Uri.parse(
        '${config.apiBase}/cgi-bin/gettoken'
        '?corpid=${Uri.encodeComponent(config.corpId)}'
        '&corpsecret=${Uri.encodeComponent(config.secret)}',
      );

      final response = await _client
          .get(url)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      final errcode = body['errcode'] as int?;
      if (errcode != null && errcode != 0) return null;

      _accessToken = body['access_token'] as String?;
      final expiresIn = body['expires_in'] as int? ?? 7200;
      // 提前5分钟过期，避免临界点问题
      _tokenExpiresAt = DateTime.now().add(Duration(seconds: expiresIn - 300));

      return _accessToken;
    } catch (e) {
      await SupportLogger.log(
        'wecom.adapter',
        'get_access_token_failed',
        extra: {'error': e.toString(), 'apiBase': config.apiBase},
      );
      return null;
    }
  }

  @override
  Future<List<ChannelChatSummary>> listChats() async {
    // 企微应用消息模式下没有"聊天列表"概念
    // 返回空，实际通过外部联系人或客户群来管理
    return const [];
  }

  @override
  Future<bool> sendMessage({
    required String peerId,
    required String text,
  }) async {
    final guard = await checkBeforeSend(peerId: peerId, text: text);
    if (!guard.allowed) return false;

    final token = await _getAccessToken();
    if (token == null) return false;

    try {
      final url = Uri.parse(
        '${config.apiBase}/cgi-bin/message/send?access_token=$token',
      );

      final body = {
        'touser': peerId,
        'msgtype': 'text',
        'agentid': int.tryParse(config.agentId) ?? 0,
        'text': {'content': text},
      };

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;

      final result = jsonDecode(response.body);
      final errcode = result['errcode'] as int?;

      // errcode=0 表示成功
      if (errcode == 0) return true;

      // token过期，清除缓存重试一次
      if (errcode == 40014 || errcode == 42001) {
        _accessToken = null;
        _tokenExpiresAt = null;
        final newToken = await _getAccessToken();
        if (newToken == null) return false;

        final retryUrl = Uri.parse(
          '${config.apiBase}/cgi-bin/message/send?access_token=$newToken',
        );
        final retryResponse = await _client
            .post(
              retryUrl,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));

        if (retryResponse.statusCode != 200) return false;
        final retryResult = jsonDecode(retryResponse.body);
        return (retryResult['errcode'] as int?) == 0;
      }

      return false;
    } catch (e) {
      await SupportLogger.log(
        'wecom.adapter',
        'send_message_failed',
        extra: {'error': e.toString(), 'peerId': peerId},
      );
      return false;
    }
  }

  /// 发送Markdown消息（企微支持富文本）
  Future<bool> sendMarkdown({
    required String peerId,
    required String markdown,
  }) async {
    final guard = await checkBeforeSend(peerId: peerId, text: markdown);
    if (!guard.allowed) return false;

    final token = await _getAccessToken();
    if (token == null) return false;

    try {
      final url = Uri.parse(
        '${config.apiBase}/cgi-bin/message/send?access_token=$token',
      );

      final body = {
        'touser': peerId,
        'msgtype': 'markdown',
        'agentid': int.tryParse(config.agentId) ?? 0,
        'markdown': {'content': markdown},
      };

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;
      final result = jsonDecode(response.body);
      return (result['errcode'] as int?) == 0;
    } catch (e) {
      await SupportLogger.log(
        'wecom.adapter',
        'send_markdown_failed',
        extra: {'error': e.toString(), 'peerId': peerId},
      );
      return false;
    }
  }

  @override
  Future<ChannelSendGuardResult> checkBeforeSend({
    required String peerId,
    required String text,
  }) async {
    if (!config.isValid) {
      return ChannelSendGuardResult.block(
        '企业微信配置不完整，请先填写corpId、agentId、secret',
      );
    }
    if (peerId.trim().isEmpty) {
      return ChannelSendGuardResult.block('目标用户ID为空');
    }
    if (text.trim().isEmpty) {
      return ChannelSendGuardResult.block('发送内容为空');
    }
    return ChannelSendGuardResult.allow(
      details: const {'official': true, 'channel': 'wecom'},
    );
  }

  @override
  Future<ChannelHealthStatus> healthCheck() async {
    final now = DateTime.now();
    final issues = config.validate();

    if (issues.isNotEmpty) {
      return ChannelHealthStatus(
        channel: channelType,
        healthy: false,
        message: '配置不完整: ${issues.join('；')}',
        checkedAt: now,
      );
    }

    // 用获取token来验证配置是否正确
    final token = await _getAccessToken();
    if (token == null) {
      return ChannelHealthStatus(
        channel: channelType,
        healthy: false,
        message: '获取access_token失败，请检查corpId和secret是否正确',
        checkedAt: now,
      );
    }

    return ChannelHealthStatus(
      channel: channelType,
      healthy: true,
      message: '企业微信已连接',
      checkedAt: now,
      details: {
        'apiBase': config.apiBase,
        'corpId': config.corpId,
        'agentId': config.agentId,
        'callbackPort': config.callbackPort,
        'callbackPath': config.callbackPath,
        'callbackUrl': config.callbackUrl,
        'tunnelPublicBaseUrl': config.tunnelPublicBaseUrl,
        'tokenValid': true,
      },
    );
  }
}
