import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dashboard/domain/financial_summary.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  TransactionRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<List<Transaction>> getTransactions({
    int limit = 50,
    int offset = 0,
    String? category,
  }) async {
    var query = _client
        .from('transactions')
        .select()
        .eq('user_id', _uid)
        .order('value_date', ascending: false)
        .range(offset, offset + limit - 1);

    if (category != null) {
      query = _client
          .from('transactions')
          .select()
          .eq('user_id', _uid)
          .eq('category', category)
          .order('value_date', ascending: false)
          .range(offset, offset + limit - 1);
    }

    final data = await query;
    return (data as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<Transaction> addTransaction({
    required double amount,
    required String description,
    required String category,
    required DateTime valueDate,
    String? accountId,
    String? merchantName,
    String? notes,
  }) async {
    final data = await _client.from('transactions').insert({
      'user_id': _uid,
      'amount': amount,
      'description': description,
      'category': category,
      'value_date': valueDate.toIso8601String().split('T').first,
      'account_id': accountId,
      'merchant_name': merchantName,
      'notes': notes,
      'is_manual': true,
    }).select().single();

    return Transaction.fromJson(data);
  }

  Future<void> updateTransaction(String id, Map<String, dynamic> updates) async {
    await _client.from('transactions').update(updates).eq('id', id);
  }

  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getMonthlySummary() async {
    final data = await _client
        .from('monthly_summary')
        .select()
        .eq('user_id', _uid)
        .order('month', ascending: false)
        .limit(12);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<CategoryBreakdown>> getCategoryBreakdown() async {
    final data = await _client
        .from('current_month_by_category')
        .select()
        .eq('user_id', _uid)
        .order('total', ascending: false);

    return (data as List)
        .map((e) => CategoryBreakdown.fromJson(e))
        .toList();
  }
}
