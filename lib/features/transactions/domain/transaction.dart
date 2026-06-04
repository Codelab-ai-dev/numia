import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  final String id;
  final String userId;
  final String? accountId;
  final String? belvoTxId;
  final double amount;
  final String currency;
  final String? description;
  final String? merchantName;
  final String? category;
  final String? categoryOverride;
  final String? subcategory;
  final DateTime valueDate;
  final bool isManual;
  final String? notes;
  final DateTime createdAt;

  const Transaction({
    required this.id,
    required this.userId,
    this.accountId,
    this.belvoTxId,
    required this.amount,
    this.currency = 'MXN',
    this.description,
    this.merchantName,
    this.category,
    this.categoryOverride,
    this.subcategory,
    required this.valueDate,
    this.isManual = true,
    this.notes,
    required this.createdAt,
  });

  bool get isExpense => amount < 0;

  String get effectiveCategory => categoryOverride ?? category ?? 'Sin categoría';

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      accountId: json['account_id'] as String?,
      belvoTxId: json['belvo_tx_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'MXN',
      description: json['description'] as String?,
      merchantName: json['merchant_name'] as String?,
      category: json['category'] as String?,
      categoryOverride: json['category_override'] as String?,
      subcategory: json['subcategory'] as String?,
      valueDate: DateTime.parse(json['value_date'] as String),
      isManual: json['is_manual'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'account_id': accountId,
        'amount': amount,
        'currency': currency,
        'description': description,
        'merchant_name': merchantName,
        'category': category,
        'category_override': categoryOverride,
        'subcategory': subcategory,
        'value_date': valueDate.toIso8601String().split('T').first,
        'is_manual': isManual,
        'notes': notes,
      };

  @override
  List<Object?> get props => [id, amount, valueDate, category];
}
