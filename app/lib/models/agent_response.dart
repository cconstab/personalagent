class AgentResponse {
  final String content;
  final String source;
  final bool wasPrivacyFiltered;
  final double confidenceScore;

  AgentResponse({
    required this.content,
    required this.source,
    this.wasPrivacyFiltered = false,
    this.confidenceScore = 1.0,
  });

  Map<String, dynamic> toJson() => {
    'content': content,
    'source': source,
    'wasPrivacyFiltered': wasPrivacyFiltered,
    'confidenceScore': confidenceScore,
  };

  factory AgentResponse.fromJson(Map<String, dynamic> json) {
    return AgentResponse(
      content: json['content'] as String,
      source: json['source'] as String,
      wasPrivacyFiltered: json['wasPrivacyFiltered'] as bool? ?? false,
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 1.0,
    );
  }
}
