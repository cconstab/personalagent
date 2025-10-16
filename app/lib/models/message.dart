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

  /// Whether this is a partial response being streamed
  final bool isPartial;

  /// Sequence number for ordering streaming chunks
  final int? chunkIndex;

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
    this.isPartial = false,
    this.chunkIndex,
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
        'isPartial': isPartial,
        if (chunkIndex != null) 'chunkIndex': chunkIndex,
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
      isPartial: json['isPartial'] as bool? ?? false,
      chunkIndex: json['chunkIndex'] as int?,
    );
  }

  /// Create a copy of this message with updated content (for streaming)
  ChatMessage copyWith({
    String? content,
    bool? isPartial,
    int? chunkIndex,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      isUser: isUser,
      timestamp: timestamp,
      source: source,
      wasPrivacyFiltered: wasPrivacyFiltered,
      isError: isError,
      agentName: agentName,
      model: model,
      isPartial: isPartial ?? this.isPartial,
      chunkIndex: chunkIndex ?? this.chunkIndex,
    );
  }
}
