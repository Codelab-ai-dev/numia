import 'package:equatable/equatable.dart';
import '../../../core/json_helpers.dart';

class BudgetAllocation extends Equatable {
  final String id;
  final String categoryId;
  final String categoryName;
  final String categoryEmoji;
  final double amount;

  const BudgetAllocation({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.amount,
  });

  factory BudgetAllocation.fromJson(Map<String, dynamic> json) {
    return BudgetAllocation(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String,
      categoryEmoji: json['category_emoji'] as String,
      amount: toDouble(json['amount']),
    );
  }

  @override
  List<Object?> get props => [id, categoryId];
}

class Budget extends Equatable {
  final String id;
  final double globalAmount;
  final int cycleStartDay;
  final List<BudgetAllocation> allocations;

  const Budget({
    required this.id,
    required this.globalAmount,
    required this.cycleStartDay,
    required this.allocations,
  });

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'] as String,
      globalAmount: toDouble(json['global_amount']),
      cycleStartDay: json['cycle_start_day'] as int,
      allocations: (json['allocations'] as List?)
              ?.map((e) => BudgetAllocation.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [id, globalAmount, cycleStartDay];
}
