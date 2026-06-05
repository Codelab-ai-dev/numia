import '../../../core/api_client.dart';
import '../domain/investment.dart';

class InvestmentRepository {
  InvestmentRepository(this._client);
  final ApiClient _client;

  Future<List<Investment>> getInvestments({bool? activeOnly}) async {
    final queryParams = <String, dynamic>{};
    if (activeOnly != null) queryParams['active_only'] = activeOnly.toString();

    final response = await _client.dio.get(
      '/api/v1/investments',
      queryParameters: queryParams,
    );
    final data = response.data as List;
    return data
        .map((e) => Investment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Investment> addInvestment({
    required String name,
    String? institution,
    required String type,
    required double amountInvested,
    double? currentValue,
    String? notes,
  }) async {
    final response = await _client.dio.post('/api/v1/investments', data: {
      'name': name,
      'institution': institution,
      'type': type,
      'amount_invested': amountInvested,
      'current_value': currentValue,
      'notes': notes,
    });
    return Investment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Investment> updateInvestment(
      String id, Map<String, dynamic> updates) async {
    final response =
        await _client.dio.put('/api/v1/investments/$id', data: updates);
    return Investment.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteInvestment(String id) async {
    await _client.dio.delete('/api/v1/investments/$id');
  }
}
