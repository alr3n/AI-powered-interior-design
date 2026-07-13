class Recommendation {
  const Recommendation({
    required this.title,
    required this.detail,
    required this.priority,
    this.estCost,
  });

  final String title;
  final String detail;
  final String priority; // high | medium | low
  final double? estCost;

  factory Recommendation.fromJson(Map<String, dynamic> j) => Recommendation(
        title: j['title'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        priority: j['priority'] as String? ?? 'medium',
        estCost: (j['estCost'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'title': title, 'detail': detail, 'priority': priority,
        if (estCost != null) 'estCost': estCost,
      };
}

class AnalysisResult {
  const AnalysisResult({
    required this.overallScore,
    required this.categoryScores,
    required this.strengths,
    required this.weaknesses,
    required this.recommendations,
    required this.assumptions,
  });

  final int overallScore;
  final Map<String, int> categoryScores;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<Recommendation> recommendations;
  final List<String> assumptions;

  static const categoryLabels = {
    'functionality': 'Functionality',
    'ergonomics': 'Ergonomics',
    'trafficFlow': 'Traffic flow',
    'lighting': 'Lighting',
    'furnitureArrangement': 'Furniture arrangement',
    'spaceUtilization': 'Space utilization',
    'storage': 'Storage',
    'visualBalance': 'Visual balance',
    'colorHarmony': 'Color harmony',
    'accessibility': 'Accessibility',
    'sustainability': 'Sustainability',
    'comfort': 'Comfort',
    'safety': 'Safety',
  };

  factory AnalysisResult.fromJson(Map<String, dynamic> j) => AnalysisResult(
        overallScore: (j['overallScore'] as num? ?? 0).toInt(),
        categoryScores: (j['categoryScores'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
        strengths: _strings(j['strengths']),
        weaknesses: _strings(j['weaknesses']),
        recommendations: (j['recommendations'] as List<dynamic>? ?? [])
            .map((r) => Recommendation.fromJson(r as Map<String, dynamic>))
            .toList(),
        assumptions: _strings(j['assumptions']),
      );

  Map<String, dynamic> toJson() => {
        'overallScore': overallScore,
        'categoryScores': categoryScores,
        'strengths': strengths,
        'weaknesses': weaknesses,
        'recommendations': recommendations.map((r) => r.toJson()).toList(),
        'assumptions': assumptions,
      };

  static List<String> _strings(dynamic v) =>
      (v as List<dynamic>? ?? []).map((e) => e.toString()).toList();
}
