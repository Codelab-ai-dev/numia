import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/ai_conversation.dart';
import '../domain/message.dart';

class ConversationRepository {
  ConversationRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<List<AiConversation>> getConversations({int limit = 20}) async {
    final data = await _client
        .from('ai_conversations')
        .select()
        .eq('user_id', _uid)
        .order('updated_at', ascending: false)
        .limit(limit);

    return (data as List).map((e) => AiConversation.fromJson(e)).toList();
  }

  Future<AiConversation?> getConversation(String id) async {
    final data = await _client
        .from('ai_conversations')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return AiConversation.fromJson(data);
  }

  Future<AiConversation> createConversation({String? title}) async {
    final data = await _client.from('ai_conversations').insert({
      'user_id': _uid,
      'title': title,
      'messages': [],
      'message_count': 0,
    }).select().single();

    return AiConversation.fromJson(data);
  }

  Future<void> appendMessages(
    String conversationId,
    List<Message> newMessages,
  ) async {
    final existing = await _client
        .from('ai_conversations')
        .select('messages, message_count')
        .eq('id', conversationId)
        .single();

    final currentMessages = List<dynamic>.from(existing['messages'] ?? []);
    for (final m in newMessages) {
      currentMessages.add({
        'id': m.id,
        'content': m.content,
        'role': m.role == MessageRole.user ? 'user' : 'assistant',
        'timestamp': m.timestamp.toIso8601String(),
      });
    }

    await _client.from('ai_conversations').update({
      'messages': currentMessages,
      'message_count': currentMessages.length,
    }).eq('id', conversationId);
  }

  Future<void> deleteConversation(String id) async {
    await _client.from('ai_conversations').delete().eq('id', id);
  }

  Future<Map<String, dynamic>?> getFinancialContext() async {
    final data = await _client.rpc('get_financial_context', params: {
      'p_user_id': _uid,
    });
    return data as Map<String, dynamic>?;
  }
}
