import 'package:equatable/equatable.dart';
import 'message.dart';

class AiConversation extends Equatable {
  final String id;
  final String? title;
  final List<Message> messages;
  final int messageCount;
  final DateTime updatedAt;

  const AiConversation({
    required this.id,
    this.title,
    this.messages = const [],
    this.messageCount = 0,
    required this.updatedAt,
  });

  /// Parses a conversation list item from GET /api/v1/coach/conversations
  /// Response: {"id":"...","title":"...","message_count":5,"updated_at":"..."}
  factory AiConversation.fromListJson(Map<String, dynamic> json) {
    return AiConversation(
      id: json['id'] as String,
      title: json['title'] as String?,
      messageCount: json['message_count'] as int? ?? 0,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Builds a full conversation from ID + messages array
  /// GET /api/v1/coach/conversations/$id returns array of
  /// {"role":"user","content":"...","timestamp":"..."}
  factory AiConversation.fromMessages(
      String id, List<dynamic> rawMessages) {
    final messages = rawMessages
        .map((m) => Message(
              id: '',
              content: m['content'] as String? ?? '',
              role: m['role'] == 'user'
                  ? MessageRole.user
                  : MessageRole.assistant,
              timestamp: m['timestamp'] != null
                  ? DateTime.parse(m['timestamp'] as String)
                  : DateTime.now(),
            ))
        .toList();

    return AiConversation(
      id: id,
      messages: messages,
      messageCount: messages.length,
      updatedAt: messages.isNotEmpty
          ? messages.last.timestamp
          : DateTime.now(),
    );
  }

  /// Legacy fromJson for backward compatibility
  factory AiConversation.fromJson(Map<String, dynamic> json) {
    return AiConversation.fromListJson(json);
  }

  @override
  List<Object?> get props => [id, messageCount];
}
