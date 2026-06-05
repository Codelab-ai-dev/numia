import '../../../core/api_client.dart';
import '../domain/ai_conversation.dart';

class ConversationRepository {
  ConversationRepository(this._client);
  final ApiClient _client;

  Future<List<AiConversation>> getConversations({int limit = 20}) async {
    final response = await _client.dio.get('/api/v1/coach/conversations');
    final data = response.data as List;
    return data
        .map((e) =>
            AiConversation.fromListJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AiConversation?> getConversation(String id) async {
    final response =
        await _client.dio.get('/api/v1/coach/conversations/$id');
    final data = response.data as List;
    return AiConversation.fromMessages(id, data);
  }

  Future<void> deleteConversation(String id) async {
    await _client.dio.delete('/api/v1/coach/conversations/$id');
  }

  Future<String> getInsight() async {
    final response = await _client.dio.get('/api/v1/coach/insight');
    final data = response.data as Map<String, dynamic>;
    return data['insight'] as String? ?? '';
  }
}
