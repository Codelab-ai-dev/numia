import '../../../core/api_client.dart';
import '../domain/account.dart';
import '../domain/financial_summary.dart';

class DashboardRepository {
  DashboardRepository(this._client);
  final ApiClient _client;

  Future<FinancialSummary> getSummary() async {
    final response = await _client.dio.get('/api/v1/dashboard/summary');
    if (response.data == null) return FinancialSummary.empty();
    return FinancialSummary.fromRpc(response.data as Map<String, dynamic>);
  }

  Future<List<Account>> getAccounts() async {
    final response = await _client.dio.get('/api/v1/accounts');
    final data = response.data as List;
    return data
        .map((e) => Account.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Account> addAccount({
    required String name,
    String? type,
    double balance = 0,
    double? creditLimit,
  }) async {
    final response = await _client.dio.post('/api/v1/accounts', data: {
      'name': name,
      'type': type,
      'balance': balance,
      'credit_limit': creditLimit,
    });
    return Account.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateAccountBalance(String id, double balance) async {
    await _client.dio.put('/api/v1/accounts/$id', data: {
      'balance': balance,
    });
  }
}
