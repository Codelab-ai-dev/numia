import '../../../core/api_client.dart';
import '../domain/goal.dart';

class GoalRepository {
  GoalRepository(this._client);
  final ApiClient _client;

  Future<List<Goal>> getGoals({String? status}) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;

    final response = await _client.dio.get(
      '/api/v1/goals',
      queryParameters: queryParams,
    );
    final data = response.data as List;
    return data
        .map((e) => Goal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Goal> addGoal({
    required String type,
    required String name,
    required double targetAmount,
    double? monthlyContribution,
    DateTime? targetDate,
    int priority = 1,
    String? emoji,
    String? notes,
  }) async {
    final response = await _client.dio.post('/api/v1/goals', data: {
      'type': type,
      'name': name,
      'target_amount': targetAmount,
      'monthly_contribution': monthlyContribution,
      'target_date': targetDate?.toIso8601String().split('T').first,
      'priority': priority,
      'emoji': emoji,
      'notes': notes,
    });
    return Goal.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateGoal(String id, Map<String, dynamic> updates) async {
    await _client.dio.put('/api/v1/goals/$id', data: updates);
  }

  Future<void> addContribution(String goalId, double amount) async {
    await _client.dio.post('/api/v1/goals/$goalId/contribute', data: {
      'amount': amount,
    });
  }

  Future<void> deleteGoal(String id) async {
    await _client.dio.delete('/api/v1/goals/$id');
  }
}
