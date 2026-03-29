class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.segment,
    required this.tags,
    required this.lastContactAt,
    required this.createdAt,
    required this.updatedAt,
    this.company,
    this.email,
    this.phone,
    this.industry,
    this.budgetLevel,
    this.isDecisionMaker = false,
    this.lifeCycleStage = 'lead',
    this.riskScore = 0,
    this.notes,
    this.preferredChannel,
    this.totalRevenue = 0,
  });

  final String id;
  final String name;
  final String segment;
  final List<String> tags;
  final DateTime? lastContactAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? company;
  final String? email;
  final String? phone;
  final String? industry;
  final String? budgetLevel; // 'low', 'medium', 'high', 'enterprise'
  final bool isDecisionMaker;
  final String lifeCycleStage; // 'lead', 'prospect', 'opportunity', 'customer', 'churned'
  final int riskScore; // 0-100
  final String? notes;
  final String? preferredChannel; // 'telegram', 'wecom'
  final double totalRevenue;

  CustomerProfile copyWith({
    String? name,
    String? segment,
    List<String>? tags,
    DateTime? lastContactAt,
    DateTime? updatedAt,
    String? company,
    String? email,
    String? phone,
    String? industry,
    String? budgetLevel,
    bool? isDecisionMaker,
    String? lifeCycleStage,
    int? riskScore,
    String? notes,
    String? preferredChannel,
    double? totalRevenue,
  }) {
    return CustomerProfile(
      id: id,
      name: name ?? this.name,
      segment: segment ?? this.segment,
      tags: tags ?? this.tags,
      lastContactAt: lastContactAt ?? this.lastContactAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      company: company ?? this.company,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      industry: industry ?? this.industry,
      budgetLevel: budgetLevel ?? this.budgetLevel,
      isDecisionMaker: isDecisionMaker ?? this.isDecisionMaker,
      lifeCycleStage: lifeCycleStage ?? this.lifeCycleStage,
      riskScore: riskScore ?? this.riskScore,
      notes: notes ?? this.notes,
      preferredChannel: preferredChannel ?? this.preferredChannel,
      totalRevenue: totalRevenue ?? this.totalRevenue,
    );
  }
}
