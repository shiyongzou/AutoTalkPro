import '../../../core/models/conversation.dart';
import '../../conversation/domain/conversation_repository.dart';
import '../../message/domain/message_repository.dart';

enum ReportPeriod { daily, weekly, monthly }

class ReportStageFunnelPoint {
  const ReportStageFunnelPoint({
    required this.stage,
    required this.count,
    required this.conversionFromPrevious,
  });

  final String stage;
  final int count;
  final double conversionFromPrevious;

  Map<String, dynamic> toJson() => {
    'stage': stage,
    'count': count,
    'conversionFromPrevious': conversionFromPrevious,
  };
}

class ReportRiskTrendPoint {
  const ReportRiskTrendPoint({required this.date, required this.count});

  final DateTime date;
  final int count;

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'count': count,
  };
}

class ReportTopRiskConversation {
  const ReportTopRiskConversation({
    required this.conversationId,
    required this.title,
    required this.riskMessageCount,
    required this.totalMessageCount,
    required this.latestRiskAt,
  });

  final String conversationId;
  final String title;
  final int riskMessageCount;
  final int totalMessageCount;
  final DateTime latestRiskAt;

  double get riskRatio {
    if (totalMessageCount <= 0) return 0;
    return riskMessageCount / totalMessageCount;
  }

  Map<String, dynamic> toJson() => {
    'conversationId': conversationId,
    'title': title,
    'riskMessageCount': riskMessageCount,
    'totalMessageCount': totalMessageCount,
    'latestRiskAt': latestRiskAt.toIso8601String(),
    'riskRatio': riskRatio,
  };
}

class ReportTopRiskCustomer {
  const ReportTopRiskCustomer({
    required this.customerId,
    required this.displayName,
    required this.riskMessageCount,
    required this.totalMessageCount,
    required this.conversationCount,
    required this.latestRiskAt,
  });

  final String customerId;
  final String displayName;
  final int riskMessageCount;
  final int totalMessageCount;
  final int conversationCount;
  final DateTime latestRiskAt;

  double get riskRatio {
    if (totalMessageCount <= 0) return 0;
    return riskMessageCount / totalMessageCount;
  }

  Map<String, dynamic> toJson() => {
    'customerId': customerId,
    'displayName': displayName,
    'riskMessageCount': riskMessageCount,
    'totalMessageCount': totalMessageCount,
    'conversationCount': conversationCount,
    'latestRiskAt': latestRiskAt.toIso8601String(),
    'riskRatio': riskRatio,
  };
}

class ReportSummary {
  const ReportSummary({
    required this.period,
    required this.generatedAt,
    required this.totalConversations,
    required this.activeConversations,
    required this.riskConversations,
    required this.totalMessages,
    required this.highlights,
    required this.stageFunnel,
    required this.riskTrend,
    required this.topRiskConversations,
    required this.topRiskCustomers,
  });

  final ReportPeriod period;
  final DateTime generatedAt;
  final int totalConversations;
  final int activeConversations;
  final int riskConversations;
  final int totalMessages;
  final List<String> highlights;
  final List<ReportStageFunnelPoint> stageFunnel;
  final List<ReportRiskTrendPoint> riskTrend;
  final List<ReportTopRiskConversation> topRiskConversations;
  final List<ReportTopRiskCustomer> topRiskCustomers;

  Map<String, dynamic> toJson() => {
    'period': period.name,
    'generatedAt': generatedAt.toIso8601String(),
    'totalConversations': totalConversations,
    'activeConversations': activeConversations,
    'riskConversations': riskConversations,
    'totalMessages': totalMessages,
    'highlights': highlights,
    'stageFunnel': stageFunnel.map((e) => e.toJson()).toList(),
    'riskTrend': riskTrend.map((e) => e.toJson()).toList(),
    'topRiskConversations': topRiskConversations
        .map((e) => e.toJson())
        .toList(),
    'topRiskCustomers': topRiskCustomers.map((e) => e.toJson()).toList(),
  };

  String toMarkdown() {
    final buffer = StringBuffer();
    final title = switch (period) {
      ReportPeriod.daily => '日报',
      ReportPeriod.weekly => '周报',
      ReportPeriod.monthly => '月报',
    };

    buffer
      ..writeln('# 销售会话$title摘要')
      ..writeln()
      ..writeln('- 生成时间: ${generatedAt.toLocal()}')
      ..writeln('- 总会话: $totalConversations')
      ..writeln('- 活跃会话: $activeConversations')
      ..writeln('- 风险会话: $riskConversations')
      ..writeln('- 消息总量: $totalMessages')
      ..writeln()
      ..writeln('## 亮点')
      ..writeln();

    for (final h in highlights) {
      buffer.writeln('- $h');
    }

    buffer
      ..writeln()
      ..writeln('## 漏斗阶段转化')
      ..writeln();

    for (final f in stageFunnel) {
      buffer.writeln(
        '- ${f.stage}: ${f.count}（环节转化 ${(f.conversionFromPrevious * 100).toStringAsFixed(1)}%）',
      );
    }

    buffer
      ..writeln()
      ..writeln('## 风险趋势')
      ..writeln();

    for (final p in riskTrend) {
      buffer.writeln('- ${_dateKey(p.date)}: ${p.count}');
    }

    buffer
      ..writeln()
      ..writeln('## Top 风险会话')
      ..writeln();

    if (topRiskConversations.isEmpty) {
      buffer.writeln('- 暂无风险会话');
    } else {
      for (final item in topRiskConversations) {
        buffer.writeln(
          '- ${item.title}（${item.conversationId}）风险消息 ${item.riskMessageCount}/${item.totalMessageCount}，最新风险时间 ${item.latestRiskAt.toLocal()}',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('## Top 高风险客户')
      ..writeln();

    if (topRiskCustomers.isEmpty) {
      buffer.writeln('- 暂无高风险客户');
    } else {
      for (final item in topRiskCustomers) {
        buffer.writeln(
          '- ${item.displayName}（${item.customerId}）风险消息 ${item.riskMessageCount}/${item.totalMessageCount}，关联会话 ${item.conversationCount}，最新风险时间 ${item.latestRiskAt.toLocal()}',
        );
      }
    }

    return buffer.toString();
  }
}

class ReportGeneratorService {
  ReportGeneratorService({
    required ConversationRepository conversationRepository,
    required MessageRepository messageRepository,
  }) : _conversationRepository = conversationRepository,
       _messageRepository = messageRepository;

  final ConversationRepository _conversationRepository;
  final MessageRepository _messageRepository;

  Future<ReportSummary> build(ReportPeriod period) async {
    final conversations = await _conversationRepository.listConversations();
    final now = DateTime.now();

    var totalMessages = 0;
    var riskConversations = 0;
    final stageCounts = <String, int>{};
    final riskCountsByDay = <DateTime, int>{};
    final riskLeaders = <ReportTopRiskConversation>[];
    final customerRiskAggregate = <String, _CustomerRiskAggregate>{};

    for (final conversation in conversations) {
      stageCounts.update(
        conversation.goalStage,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      final messages = await _messageRepository.listMessages(conversation.id);
      totalMessages += messages.length;

      final riskMessages = messages.where((m) => m.riskFlag).toList();
      if (riskMessages.isNotEmpty) {
        riskConversations += 1;

        riskMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
        final latestRiskAt = riskMessages.last.sentAt;
        riskLeaders.add(
          ReportTopRiskConversation(
            conversationId: conversation.id,
            title: conversation.title,
            riskMessageCount: riskMessages.length,
            totalMessageCount: messages.length,
            latestRiskAt: latestRiskAt,
          ),
        );

        customerRiskAggregate.update(
          conversation.customerId,
          (value) {
            value.riskMessageCount += riskMessages.length;
            value.totalMessageCount += messages.length;
            value.conversationIds.add(conversation.id);
            if (value.displayName == value.customerId &&
                conversation.title.trim().isNotEmpty) {
              value.displayName = conversation.title.trim();
            }
            if (latestRiskAt.isAfter(value.latestRiskAt)) {
              value.latestRiskAt = latestRiskAt;
            }
            return value;
          },
          ifAbsent: () => _CustomerRiskAggregate(
            customerId: conversation.customerId,
            displayName: conversation.title.trim().isEmpty
                ? conversation.customerId
                : conversation.title.trim(),
            riskMessageCount: riskMessages.length,
            totalMessageCount: messages.length,
            latestRiskAt: latestRiskAt,
            conversationIds: {conversation.id},
          ),
        );

        for (final risk in riskMessages) {
          final day = DateTime(
            risk.sentAt.year,
            risk.sentAt.month,
            risk.sentAt.day,
          );
          riskCountsByDay.update(day, (value) => value + 1, ifAbsent: () => 1);
        }
      }
    }

    final activeConversations = conversations.where(_isActive).length;
    final highlights = _buildHighlights(
      period: period,
      conversations: conversations,
      totalMessages: totalMessages,
      activeConversations: activeConversations,
      riskConversations: riskConversations,
    );

    riskLeaders.sort((a, b) {
      final byRisk = b.riskMessageCount.compareTo(a.riskMessageCount);
      if (byRisk != 0) return byRisk;
      return b.latestRiskAt.compareTo(a.latestRiskAt);
    });

    final topRiskCustomers =
        customerRiskAggregate.values
            .map(
              (item) => ReportTopRiskCustomer(
                customerId: item.customerId,
                displayName: item.displayName,
                riskMessageCount: item.riskMessageCount,
                totalMessageCount: item.totalMessageCount,
                conversationCount: item.conversationIds.length,
                latestRiskAt: item.latestRiskAt,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byRisk = b.riskMessageCount.compareTo(a.riskMessageCount);
            if (byRisk != 0) return byRisk;
            return b.latestRiskAt.compareTo(a.latestRiskAt);
          });

    return ReportSummary(
      period: period,
      generatedAt: now,
      totalConversations: conversations.length,
      activeConversations: activeConversations,
      riskConversations: riskConversations,
      totalMessages: totalMessages,
      highlights: highlights,
      stageFunnel: _buildStageFunnel(stageCounts),
      riskTrend: _buildRiskTrend(period, now, riskCountsByDay),
      topRiskConversations: riskLeaders.take(5).toList(growable: false),
      topRiskCustomers: topRiskCustomers.take(5).toList(growable: false),
    );
  }

  bool _isActive(Conversation conversation) {
    if (conversation.lastMessageAt == null) return false;
    return DateTime.now().difference(conversation.lastMessageAt!).inDays <= 7;
  }

  List<String> _buildHighlights({
    required ReportPeriod period,
    required List<Conversation> conversations,
    required int totalMessages,
    required int activeConversations,
    required int riskConversations,
  }) {
    final title = switch (period) {
      ReportPeriod.daily => '日报',
      ReportPeriod.weekly => '周报',
      ReportPeriod.monthly => '月报',
    };

    return [
      '$title总会话数: ${conversations.length}',
      '$title活跃会话数: $activeConversations',
      '$title风险会话数: $riskConversations',
      '$title消息总量: $totalMessages',
    ];
  }

  List<ReportStageFunnelPoint> _buildStageFunnel(Map<String, int> stageCounts) {
    if (stageCounts.isEmpty) return const [];

    const preferredOrder = ['discover', 'proposal', 'closing'];
    final orderedStages = <String>[];

    for (final stage in preferredOrder) {
      if (stageCounts.containsKey(stage)) {
        orderedStages.add(stage);
      }
    }

    final extras =
        stageCounts.keys.where((key) => !preferredOrder.contains(key)).toList()
          ..sort();
    orderedStages.addAll(extras);

    final result = <ReportStageFunnelPoint>[];
    int? previousCount;
    for (final stage in orderedStages) {
      final count = stageCounts[stage] ?? 0;
      final conversion = previousCount == null
          ? 1.0
          : (previousCount == 0 ? 0.0 : count / previousCount);
      result.add(
        ReportStageFunnelPoint(
          stage: stage,
          count: count,
          conversionFromPrevious: conversion,
        ),
      );
      previousCount = count;
    }
    return result;
  }

  List<ReportRiskTrendPoint> _buildRiskTrend(
    ReportPeriod period,
    DateTime now,
    Map<DateTime, int> riskCountsByDay,
  ) {
    final windowDays = switch (period) {
      ReportPeriod.daily => 7,
      ReportPeriod.weekly => 14,
      ReportPeriod.monthly => 30,
    };

    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: windowDays - 1));

    final points = <ReportRiskTrendPoint>[];
    for (var i = 0; i < windowDays; i++) {
      final day = start.add(Duration(days: i));
      points.add(
        ReportRiskTrendPoint(date: day, count: riskCountsByDay[day] ?? 0),
      );
    }

    return points;
  }
}

class _CustomerRiskAggregate {
  _CustomerRiskAggregate({
    required this.customerId,
    required this.displayName,
    required this.riskMessageCount,
    required this.totalMessageCount,
    required this.latestRiskAt,
    required this.conversationIds,
  });

  final String customerId;
  String displayName;
  int riskMessageCount;
  int totalMessageCount;
  DateTime latestRiskAt;
  final Set<String> conversationIds;
}

String _dateKey(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
