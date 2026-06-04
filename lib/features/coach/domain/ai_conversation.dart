import 'package:equatable/equatable.dart';
import 'message.dart';

class AiConversation extends Equatable {
  final String id;
  final String userId;
  final String? title;
  final List<Message> messages;
  final Map<String, dynamic>? contextSnapshot;
  final int messageCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiConversation({
    required this.id,
    required this.userId,
    this.title,
    this.messages = const [],
    this.contextSnapshot,
    this.messageCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? [];
    return AiConversation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String?,
      messages: rawMessages
          .map((m) => Message(
                id: m['id'] as String? ?? '',
                content: m['content'] as String? ?? '',
                role: m['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
                timestamp: m['timestamp'] != null
                    ? DateTime.parse(m['timestamp'] as String)
                    : DateTime.now(),
              ))
          .toList(),
      contextSnapshot: json['context_snapshot'] as Map<String, dynamic>?,
      messageCount: json['message_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'title': title,
        'messages': messages
            .map((m) => {
                  'id': m.id,
                  'content': m.content,
                  'role': m.role == MessageRole.user ? 'user' : 'assistant',
                  'timestamp': m.timestamp.toIso8601String(),
                })
            .toList(),
        'context_snapshot': contextSnapshot,
        'message_count': messages.length,
      };

  @override
  List<Object?> get props => [id, userId, messageCount];
}
