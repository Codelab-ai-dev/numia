import 'package:equatable/equatable.dart';

class Account extends Equatable {
  final String id;
  final String userId;
  final String? connectionId;
  final String? belvoAccountId;
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
    this.connectionId,
    this.belvoAccountId,
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
      connectionId: json['connection_id'] as String?,
      belvoAccountId: json['belvo_account_id'] as String?,
      name: json['name'] as String,
      type: json['type'] as String?,
      currency: json['currency'] as String? ?? 'MXN',
      balance: (json['balance'] as num).toDouble(),
      creditLimit: json['credit_limit'] != null
          ? (json['credit_limit'] as num).toDouble()
          : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'connection_id': connectionId,
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
