import 'package:equatable/equatable.dart';

class Goal extends Equatable {
  final String id;
  final String userId;
  final String type;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final double? monthlyContribution;
  final DateTime? targetDate;
  final int priority;
  final String status;
  final String? emoji;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Goal({
    required this.id,
    required this.userId,
    required this.type,
    required this.name,
    required this.targetAmount,
    this.currentAmount = 0,
    this.monthlyContribution,
    this.targetDate,
    this.priority = 1,
    this.status = 'active',
    this.emoji,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;

  bool get isActive => status == 'active';

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      monthlyContribution: json['monthly_contribution'] != null
          ? (json['monthly_contribution'] as num).toDouble()
          : null,
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'] as String)
          : null,
      priority: json['priority'] as int? ?? 1,
      status: json['status'] as String? ?? 'active',
      emoji: json['emoji'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'type': type,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': currentAmount,
        'monthly_contribution': monthlyContribution,
        'target_date': targetDate?.toIso8601String().split('T').first,
        'priority': priority,
        'status': status,
        'emoji': emoji,
        'notes': notes,
      };

  @override
  List<Object?> get props => [id, name, targetAmount, currentAmount, status];
}
