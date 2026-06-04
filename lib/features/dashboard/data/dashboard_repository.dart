import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/account.dart';
import '../domain/debt.dart';
import '../domain/financial_summary.dart';

class DashboardRepository {
  DashboardRepository(this._client);
  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Future<FinancialSummary> getSummary() async {
    final data = await _client.rpc('get_dashboard_summary');
    if (data == null) return FinancialSummary.empty();
    return FinancialSummary.fromRpc(data as Map<String, dynamic>);
  }

  Future<List<Account>> getAccounts() async {
    final data = await _client
        .from('accounts')
        .select()
        .eq('user_id', _uid)
        .eq('is_active', true)
        .order('created_at');

    return (data as List).map((e) => Account.fromJson(e)).toList();
  }

  Future<Account> addAccount({
    required String name,
    String? type,
    double balance = 0,
    double? creditLimit,
  }) async {
    final data = await _client.from('accounts').insert({
      'user_id': _uid,
      'name': name,
      'type': type,
      'balance': balance,
      'credit_limit': creditLimit,
    }).select().single();

    return Account.fromJson(data);
  }

  Future<void> updateAccountBalance(String id, double balance) async {
    await _client.from('accounts').update({'balance': balance}).eq('id', id);
  }

  Future<List<Debt>> getDebts({bool activeOnly = true}) async {
    var query = _client
        .from('debts')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false);

    if (activeOnly) {
      query = _client
          .from('debts')
          .select()
          .eq('user_id', _uid)
          .eq('is_active', true)
          .order('created_at', ascending: false);
    }

    final data = await query;
    return (data as List).map((e) => Debt.fromJson(e)).toList();
  }

  Future<Debt> addDebt({
    required String type,
    required String name,
    required double totalAmount,
    String? institution,
    double? originalAmount,
    double? monthlyPayment,
    double? interestRate,
    String? notes,
  }) async {
    final data = await _client.from('debts').insert({
      'user_id': _uid,
      'type': type,
      'name': name,
      'total_amount': totalAmount,
      'institution': institution,
      'original_amount': originalAmount,
      'monthly_payment': monthlyPayment,
      'interest_rate': interestRate,
      'notes': notes,
    }).select().single();

    return Debt.fromJson(data);
  }

  Future<void> updateDebt(String id, Map<String, dynamic> updates) async {
    await _client.from('debts').update(updates).eq('id', id);
  }
}
