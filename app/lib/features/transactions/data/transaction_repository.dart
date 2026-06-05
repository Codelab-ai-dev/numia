import '../../../core/api_client.dart';
import '../../../core/json_helpers.dart';
import '../../dashboard/domain/financial_summary.dart';
import '../domain/transaction.dart';

class TransactionRepository {
  TransactionRepository(this._client);
  final ApiClient _client;

  Future<List<Transaction>> getTransactions({
    int limit = 50,
    int offset = 0,
    String? category,
  }) async {
    final queryParams = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (category != null) queryParams['category'] = category;

    final response = await _client.dio.get(
      '/api/v1/transactions',
      queryParameters: queryParams,
    );
    final data = response.data as List;
    return data
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
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
    final response = await _client.dio.post('/api/v1/transactions', data: {
      'account_id': accountId,
      'amount': amount,
      'currency': 'MXN',
      'description': description,
      'merchant_name': merchantName,
      'category': category,
      'value_date': valueDate.toIso8601String().split('T').first,
      'is_manual': true,
      'notes': notes,
    });
    return Transaction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateTransaction(
      String id, Map<String, dynamic> updates) async {
    await _client.dio.put('/api/v1/transactions/$id', data: updates);
  }

  Future<void> deleteTransaction(String id) async {
    await _client.dio.delete('/api/v1/transactions/$id');
  }

  /// Returns monthly summary for the current month.
  /// Response: {"income":"123.45","expenses":"67.89","net":"55.56","tx_count":10}
  Future<Map<String, dynamic>> getMonthlySummary() async {
    final response = await _client.dio.get('/api/v1/transactions/summary');
    final data = response.data as Map<String, dynamic>;
    return {
      'income': toDouble(data['income']),
      'expenses': toDouble(data['expenses']),
      'net': toDouble(data['net']),
      'tx_count': (data['tx_count'] as num?)?.toInt() ?? 0,
    };
  }

  Future<List<CategoryBreakdown>> getCategoryBreakdown() async {
    final response = await _client.dio.get('/api/v1/transactions/categories');
    final data = response.data as List;
    return data
        .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
