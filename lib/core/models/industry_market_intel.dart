class IndustryMarketIntel {
  const IndustryMarketIntel({
    required this.id,
    required this.industry,
    required this.templateName,
    required this.trendSummary,
    required this.priceBand,
    required this.competitorHighlights,
    required this.weeklySuggestion,
    required this.updatedAt,
  });

  final String id;
  final String industry;
  final String templateName;
  final String trendSummary;
  final String priceBand;
  final List<String> competitorHighlights;
  final String weeklySuggestion;
  final DateTime updatedAt;

  IndustryMarketIntel copyWith({
    String? trendSummary,
    String? priceBand,
    List<String>? competitorHighlights,
    String? weeklySuggestion,
    DateTime? updatedAt,
  }) {
    return IndustryMarketIntel(
      id: id,
      industry: industry,
      templateName: templateName,
      trendSummary: trendSummary ?? this.trendSummary,
      priceBand: priceBand ?? this.priceBand,
      competitorHighlights: competitorHighlights ?? this.competitorHighlights,
      weeklySuggestion: weeklySuggestion ?? this.weeklySuggestion,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
