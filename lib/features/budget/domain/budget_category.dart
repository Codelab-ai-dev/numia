import 'package:equatable/equatable.dart';

class BudgetCategory extends Equatable {
  final String id;
  final String name;
  final String emoji;
  final bool isCustom;
  final bool isActive;

  const BudgetCategory({
    required this.id,
    required this.name,
    required this.emoji,
    this.isCustom = false,
    this.isActive = true,
  });

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    return BudgetCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      isCustom: json['is_custom'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [id, name, emoji];
}
