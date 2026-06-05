import 'package:equatable/equatable.dart';
import '../../../core/json_helpers.dart';

class Investment extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? institution;
  final String type;
  final double amountInvested;
  final double currentValue;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Investment({
    required this.id,
    required this.userId,
    required this.name,
    this.institution,
    required this.type,
    required this.amountInvested,
    required this.currentValue,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Absolute gain/loss vs. the amount originally invested.
  double get returnAmount => currentValue - amountInvested;

  /// Percentage gain/loss vs. the amount originally invested.
  double get returnPct =>
      amountInvested > 0 ? (returnAmount / amountInvested) * 100 : 0;

  factory Investment.fromJson(Map<String, dynamic> json) {
    return Investment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      institution: json['institution'] as String?,
      type: json['type'] as String,
      amountInvested: toDouble(json['amount_invested']),
      currentValue: toDouble(json['current_value']),
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  @override
  List<Object?> get props =>
      [id, name, institution, type, amountInvested, currentValue, isActive];
}
