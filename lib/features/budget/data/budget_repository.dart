import '../../../core/api_client.dart';
import '../domain/budget.dart';
import '../domain/budget_category.dart';
import '../domain/budget_summary.dart';
import '../domain/expense.dart';

class BudgetRepository {
  BudgetRepository(this._client);
  final ApiClient _client;

  Future<List<BudgetCategory>> getCategories() async {
    final response = await _client.dio.get('/api/v1/budget/categories');
    final data = response.data as List;
    return data
        .map((e) => BudgetCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BudgetCategory> createCategory({
    required String name,
    required String emoji,
  }) async {
    final response = await _client.dio.post('/api/v1/budget/categories', data: {
      'name': name,
      'emoji': emoji,
    });
    return BudgetCategory.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) async {
    await _client.dio.delete('/api/v1/budget/categories/$id');
  }

  Future<Budget?> getBudget() async {
    final response = await _client.dio.get('/api/v1/budget');
    if (response.data == null) return null;
    return Budget.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Budget> createOrUpdateBudget({
    required double globalAmount,
    required int cycleStartDay,
  }) async {
    final response = await _client.dio.post('/api/v1/budget', data: {
      'global_amount': globalAmount,
      'cycle_start_day': cycleStartDay,
    });
    return Budget.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setAllocations(List<Map<String, dynamic>> allocations) async {
    await _client.dio.put('/api/v1/budget/allocations', data: {
      'items': allocations,
    });
  }

  Future<List<Expense>> getExpenses({String? start, String? end}) async {
    final params = <String, dynamic>{};
    if (start != null) params['start'] = start;
    if (end != null) params['end'] = end;
    final response = await _client.dio.get('/api/v1/budget/expenses', queryParameters: params);
    final data = response.data as List;
    return data
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createExpense({
    required String categoryId,
    required double amount,
    required String expenseDate,
    String? description,
    String? subcategory,
  }) async {
    await _client.dio.post('/api/v1/budget/expenses', data: {
      'category_id': categoryId,
      'amount': amount,
      'expense_date': expenseDate,
      if (description != null) 'description': description,
      if (subcategory != null) 'subcategory': subcategory,
    });
  }

  Future<void> updateExpense({
    required String id,
    required String categoryId,
    required double amount,
    required String expenseDate,
    String? description,
    String? subcategory,
  }) async {
    await _client.dio.put('/api/v1/budget/expenses/$id', data: {
      'category_id': categoryId,
      'amount': amount,
      'expense_date': expenseDate,
      if (description != null) 'description': description,
      if (subcategory != null) 'subcategory': subcategory,
    });
  }

  Future<void> deleteExpense(String id) async {
    await _client.dio.delete('/api/v1/budget/expenses/$id');
  }

  Future<BudgetSummary> getSummary() async {
    final response = await _client.dio.get('/api/v1/budget/summary');
    return BudgetSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> registerDevice({
    required String fcmToken,
    required String platform,
  }) async {
    await _client.dio.post('/api/v1/devices', data: {
      'fcm_token': fcmToken,
      'platform': platform,
    });
  }

  Future<void> removeDevice(String fcmToken) async {
    await _client.dio.delete('/api/v1/devices', data: {
      'fcm_token': fcmToken,
    });
  }
}
