import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

/// Types of messages exchanged between app and agent
enum MessageType { query, response, contextUpdate, error }

/// Source of the AI response
enum ResponseSource {
  ollama,
  claude,
  hybrid, // Ollama + Claude combination
}

@JsonSerializable()
class AgentMessage {
  final String id;
  final MessageType type;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  AgentMessage({
    required this.id,
    required this.type,
    required this.content,
    required this.timestamp,
    this.metadata,
  });

  factory AgentMessage.fromJson(Map<String, dynamic> json) =>
      _$AgentMessageFromJson(json);

  Map<String, dynamic> toJson() => _$AgentMessageToJson(this);
}

@JsonSerializable()
class QueryMessage extends AgentMessage {
  final String userId;
  final List<String>? contextKeys;
  final bool useOllamaOnly;
  final List<Map<String, dynamic>>? conversationHistory;
  final String?
  conversationId; // For routing responses back to correct conversation

  /// The notification ID from atPlatform - used for mutex coordination
  @JsonKey(includeFromJson: false, includeToJson: false)
  final String? notificationId;

  QueryMessage({
    required String id,
    required String content,
    required this.userId,
    this.contextKeys,
    this.useOllamaOnly = false,
    this.conversationHistory,
    this.conversationId,
    this.notificationId,
    DateTime? timestamp,
  }) : super(
         id: id,
         type: MessageType.query,
         content: content,
         timestamp: timestamp ?? DateTime.now(),
       );

  factory QueryMessage.fromJson(Map<String, dynamic> json) =>
      _$QueryMessageFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$QueryMessageToJson(this);
}

@JsonSerializable()
class ResponseMessage extends AgentMessage {
  final ResponseSource source;
  final bool wasPrivacyFiltered;
  final double confidenceScore;
  final String? agentName;
  final String? model;
  final String? conversationId; // Echo back for routing

  /// Whether this is a partial response (streaming in progress)
  final bool isPartial;

  /// Sequence number for ordering streaming chunks
  final int? chunkIndex;

  ResponseMessage({
    required String id,
    required String content,
    required this.source,
    this.wasPrivacyFiltered = false,
    this.confidenceScore = 1.0,
    this.agentName,
    this.model,
    this.conversationId,
    this.isPartial = false,
    this.chunkIndex,
    DateTime? timestamp,
  }) : super(
         id: id,
         type: MessageType.response,
         content: content,
         timestamp: timestamp ?? DateTime.now(),
         metadata: {
           'source': source.name,
           'wasPrivacyFiltered': wasPrivacyFiltered,
           'confidenceScore': confidenceScore,
           if (agentName != null) 'agentName': agentName,
           if (model != null) 'model': model,
           if (conversationId != null) 'conversationId': conversationId,
           'isPartial': isPartial,
           if (chunkIndex != null) 'chunkIndex': chunkIndex,
         },
       );

  factory ResponseMessage.fromJson(Map<String, dynamic> json) =>
      _$ResponseMessageFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$ResponseMessageToJson(this);
}

@JsonSerializable()
class ContextData {
  final String key;
  final String value;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final List<String> tags;

  ContextData({
    required this.key,
    required this.value,
    required this.createdAt,
    this.expiresAt,
    this.tags = const [],
  });

  factory ContextData.fromJson(Map<String, dynamic> json) =>
      _$ContextDataFromJson(json);

  Map<String, dynamic> toJson() => _$ContextDataToJson(this);
}
