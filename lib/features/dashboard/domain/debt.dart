import 'package:equatable/equatable.dart';

class Debt extends Equatable {
  final String id;
  final String userId;
  final String type;
  final String name;
  final String? institution;
  final double totalAmount;
  final double? originalAmount;
  final double? monthlyPayment;
  final double? interestRate;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Debt({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    this.institution,
    required this.totalAmount,
    this.originalAmount,
    this.monthlyPayment,
    this.interestRate,
    this.isActive = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get paidPercentage {
    if (originalAmount == null || originalAmount == 0) return 0;
    return ((originalAmount! - totalAmount) / originalAmount!).clamp(0.0, 1.0);
  }

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      institution: json['institution'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      originalAmount: json['original_amount'] != null
          ? (json['original_amount'] as num).toDouble()
          : null,
      monthlyPayment: json['monthly_payment'] != null
          ? (json['monthly_payment'] as num).toDouble()
          : null,
      interestRate: json['interest_rate'] != null
          ? (json['interest_rate'] as num).toDouble()
          : null,
      isActive: json['is_active'] as bool? ?? true,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'type': type,
        'name': name,
        'institution': institution,
        'total_amount': totalAmount,
        'original_amount': originalAmount,
        'monthly_payment': monthlyPayment,
        'interest_rate': interestRate,
        'is_active': isActive,
        'notes': notes,
      };

  @override
  List<Object?> get props => [id, name, totalAmount, isActive];
}
