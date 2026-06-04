import 'package:equatable/equatable.dart';
import '../../../core/json_helpers.dart';

class Account extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? type;
  final String currency;
  final double balance;
  final double? creditLimit;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    required this.id,
    required this.userId,
    required this.name,
    this.type,
    this.currency = 'MXN',
    this.balance = 0,
    this.creditLimit,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: json['type'] as String?,
      currency: json['currency'] as String? ?? 'MXN',
      balance: toDouble(json['balance']),
      creditLimit: toDoubleOrNull(json['credit_limit']),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'type': type,
        'currency': currency,
        'balance': balance,
        'credit_limit': creditLimit,
        'is_active': isActive,
      };

  @override
  List<Object?> get props => [id, name, balance, isActive];
}
