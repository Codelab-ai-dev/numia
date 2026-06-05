import 'package:equatable/equatable.dart';
import '../../../core/json_helpers.dart';

class BudgetSummary extends Equatable {
  final CycleInfo cycle;
  final GlobalBudgetSummary global;
  final List<CategoryBudgetSummary> categories;
  final double unallocatedSpent;

  const BudgetSummary({
    required this.cycle,
    required this.global,
    required this.categories,
    required this.unallocatedSpent,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    return BudgetSummary(
      cycle: CycleInfo.fromJson(json['cycle'] as Map<String, dynamic>),
      global: GlobalBudgetSummary.fromJson(json['global'] as Map<String, dynamic>),
      categories: (json['categories'] as List?)
              ?.map((e) => CategoryBudgetSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      unallocatedSpent: toDouble(json['unallocated_spent'] ?? 0),
    );
  }

  @override
  List<Object?> get props => [cycle, global];
}

class CycleInfo extends Equatable {
  final String start;
  final String end;

  const CycleInfo({required this.start, required this.end});

  factory CycleInfo.fromJson(Map<String, dynamic> json) {
    return CycleInfo(
      start: json['start'] as String,
      end: json['end'] as String,
    );
  }

  int get remainingDays {
    final endDate = DateTime.parse(end);
    return endDate.difference(DateTime.now()).inDays.clamp(0, 999);
  }

  @override
  List<Object?> get props => [start, end];
}

class GlobalBudgetSummary extends Equatable {
  final double budgeted;
  final double spent;
  final double percentage;

  const GlobalBudgetSummary({
    required this.budgeted,
    required this.spent,
    required this.percentage,
  });

  factory GlobalBudgetSummary.fromJson(Map<String, dynamic> json) {
    return GlobalBudgetSummary(
      budgeted: toDouble(json['total_budget'] ?? json['budgeted']),
      spent: toDouble(json['total_spent'] ?? json['spent']),
      percentage: toDouble(json['percentage']),
    );
  }

  @override
  List<Object?> get props => [budgeted, spent, percentage];
}

class CategoryBudgetSummary extends Equatable {
  final String categoryId;
  final String name;
  final String emoji;
  final double budgeted;
  final double spent;
  final double percentage;

  const CategoryBudgetSummary({
    required this.categoryId,
    required this.name,
    required this.emoji,
    required this.budgeted,
    required this.spent,
    required this.percentage,
  });

  factory CategoryBudgetSummary.fromJson(Map<String, dynamic> json) {
    return CategoryBudgetSummary(
      categoryId: json['category_id'] as String,
      name: (json['category_name'] ?? json['name']) as String,
      emoji: (json['category_emoji'] ?? json['emoji']) as String,
      budgeted: toDouble(json['allocated'] ?? json['budgeted']),
      spent: toDouble(json['spent']),
      percentage: toDouble(json['percentage']),
    );
  }

  @override
  List<Object?> get props => [categoryId, name, budgeted, spent];
}
