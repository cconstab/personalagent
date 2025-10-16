enum ResponseSource { ollama, claude, hybrid }

class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final ResponseSource? source;
  final bool wasPrivacyFiltered;
  final bool isError;
  final String? agentName;
  final String? model;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.source,
    this.wasPrivacyFiltered = false,
    this.isError = false,
    this.agentName,
    this.model,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'source': source?.name,
        'wasPrivacyFiltered': wasPrivacyFiltered,
        'isError': isError,
        if (agentName != null) 'agentName': agentName,
        if (model != null) 'model': model,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      source: json['source'] != null
          ? ResponseSource.values.firstWhere(
              (e) => e.name == json['source'],
              orElse: () => ResponseSource.ollama,
            )
          : null,
      wasPrivacyFiltered: json['wasPrivacyFiltered'] as bool? ?? false,
      isError: json['isError'] as bool? ?? false,
      agentName: json['agentName'] as String?,
      model: json['model'] as String?,
    );
  }
}
