import 'package:equatable/equatable.dart';
import '../../../core/json_helpers.dart';

class Expense extends Equatable {
  final String id;
  final String categoryId;
  final String? categoryName;
  final String? categoryEmoji;
  final double amount;
  final String? description;
  final String? subcategory;
  final DateTime expenseDate;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.categoryId,
    this.categoryName,
    this.categoryEmoji,
    required this.amount,
    this.description,
    this.subcategory,
    required this.expenseDate,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      categoryName: json['category_name'] as String?,
      categoryEmoji: json['category_emoji'] as String?,
      amount: toDouble(json['amount']),
      description: json['description'] as String?,
      subcategory: json['subcategory'] as String?,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, categoryId, amount];
}
