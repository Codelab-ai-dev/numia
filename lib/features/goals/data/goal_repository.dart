import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/goal.dart';

class GoalRepository {
  GoalRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<List<Goal>> getGoals({String? status}) async {
    var query = _client
        .from('goals')
        .select()
        .eq('user_id', _uid)
        .order('priority')
        .order('created_at', ascending: false);

    if (status != null) {
      query = _client
          .from('goals')
          .select()
          .eq('user_id', _uid)
          .eq('status', status)
          .order('priority')
          .order('created_at', ascending: false);
    }

    final data = await query;
    return (data as List).map((e) => Goal.fromJson(e)).toList();
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
    final data = await _client.from('goals').insert({
      'user_id': _uid,
      'type': type,
      'name': name,
      'target_amount': targetAmount,
      'current_amount': 0,
      'monthly_contribution': monthlyContribution,
      'target_date': targetDate?.toIso8601String().split('T').first,
      'priority': priority,
      'emoji': emoji,
      'notes': notes,
    }).select().single();

    return Goal.fromJson(data);
  }

  Future<void> updateGoal(String id, Map<String, dynamic> updates) async {
    await _client.from('goals').update(updates).eq('id', id);
  }

  Future<void> addContribution(String goalId, double amount) async {
    final goal = await _client
        .from('goals')
        .select('current_amount')
        .eq('id', goalId)
        .single();

    final current = (goal['current_amount'] as num).toDouble();
    await _client.from('goals').update({
      'current_amount': current + amount,
    }).eq('id', goalId);
  }

  Future<void> deleteGoal(String id) async {
    await _client.from('goals').delete().eq('id', id);
  }
}
