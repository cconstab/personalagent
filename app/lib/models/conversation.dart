import 'message.dart';

/// Represents a conversation thread with an AI agent
class Conversation {
  /// Unique identifier for this conversation
  final String id;

  /// User-defined title for the conversation
  String title;

  /// Messages in this conversation
  final List<ChatMessage> messages;

  /// When this conversation was created
  final DateTime createdAt;

  /// When this conversation was last updated
  DateTime updatedAt;

  Conversation({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Generate a default title from the first user message
  static String generateTitle(List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return 'New Conversation';
    }

    final firstUserMessage =
        messages.firstWhere((m) => m.isUser, orElse: () => messages.first);

    final content = firstUserMessage.content.trim();
    if (content.length <= 50) {
      return content;
    }

    // Take first 47 characters and add ellipsis
    return '${content.substring(0, 47)}...';
  }

  /// Update the conversation title automatically
  void autoUpdateTitle() {
    if (messages.isEmpty) {
      title = 'New Conversation';
    } else if (title == 'New Conversation' || title.isEmpty) {
      title = generateTitle(messages);
    }
  }

  /// JSON serialization
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'messages': messages.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Conversation copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
