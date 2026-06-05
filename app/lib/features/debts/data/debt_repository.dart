import '../../../core/api_client.dart';
import '../../dashboard/domain/debt.dart';

class DebtRepository {
  DebtRepository(this._client);
  final ApiClient _client;

  Future<List<Debt>> getDebts({bool activeOnly = true}) async {
    final response = await _client.dio.get(
      '/api/v1/debts',
      queryParameters: {'active_only': activeOnly},
    );
    final data = response.data as List;
    return data.map((e) => Debt.fromJson(e as Map<String, dynamic>)).toList();
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
    final response = await _client.dio.post('/api/v1/debts', data: {
      'type': type,
      'name': name,
      'total_amount': totalAmount,
      'institution': institution,
      'original_amount': originalAmount,
      'monthly_payment': monthlyPayment,
      'interest_rate': interestRate,
      'notes': notes,
    });
    return Debt.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Debt> updateDebt(String id, Map<String, dynamic> updates) async {
    final response = await _client.dio.put('/api/v1/debts/$id', data: updates);
    return Debt.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteDebt(String id) async {
    await _client.dio.delete('/api/v1/debts/$id');
  }
}
