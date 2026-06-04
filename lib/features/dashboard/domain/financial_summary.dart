import 'package:equatable/equatable.dart';

class FinancialSummary extends Equatable {
  final double totalAssets;
  final double totalDebt;
  final double netWorth;
  final double monthIncome;
  final double monthExpenses;
  final double monthNet;
  final int txCount;
  final List<ActiveGoalSummary> activeGoals;
  final List<ActiveDebtSummary> activeDebts;
  final int unreadInsights;

  const FinancialSummary({
    required this.totalAssets,
    required this.totalDebt,
    required this.netWorth,
    required this.monthIncome,
    required this.monthExpenses,
    required this.monthNet,
    required this.txCount,
    required this.activeGoals,
    required this.activeDebts,
    required this.unreadInsights,
  });

  factory FinancialSummary.empty() => const FinancialSummary(
        totalAssets: 0,
        totalDebt: 0,
        netWorth: 0,
        monthIncome: 0,
        monthExpenses: 0,
        monthNet: 0,
        txCount: 0,
        activeGoals: [],
        activeDebts: [],
        unreadInsights: 0,
      );

  /// Parses the JSON from `get_dashboard_summary` RPC
  factory FinancialSummary.fromRpc(Map<String, dynamic> json) {
    final nw = json['net_worth'] as Map<String, dynamic>? ?? {};
    final ms = json['monthly_summary'] as Map<String, dynamic>? ?? {};
    final goals = json['active_goals'] as List<dynamic>? ?? [];
    final debts = json['active_debts'] as List<dynamic>? ?? [];

    return FinancialSummary(
      totalAssets: (nw['total_assets'] as num?)?.toDouble() ?? 0,
      totalDebt: (nw['total_debt'] as num?)?.toDouble() ?? 0,
      netWorth: (nw['net_worth'] as num?)?.toDouble() ?? 0,
      monthIncome: (ms['income'] as num?)?.toDouble() ?? 0,
      monthExpenses: (ms['expenses'] as num?)?.toDouble() ?? 0,
      monthNet: (ms['net'] as num?)?.toDouble() ?? 0,
      txCount: (ms['tx_count'] as num?)?.toInt() ?? 0,
      activeGoals: goals
          .map((g) => ActiveGoalSummary.fromJson(g as Map<String, dynamic>))
          .toList(),
      activeDebts: debts
          .map((d) => ActiveDebtSummary.fromJson(d as Map<String, dynamic>))
          .toList(),
      unreadInsights: (json['unread_insights'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [netWorth, monthIncome, monthExpenses, totalDebt];
}

class ActiveGoalSummary extends Equatable {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? emoji;

  const ActiveGoalSummary({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.emoji,
  });

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;

  factory ActiveGoalSummary.fromJson(Map<String, dynamic> json) {
    return ActiveGoalSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      targetAmount: (json['target_amount'] as num).toDouble(),
      currentAmount: (json['current_amount'] as num).toDouble(),
      emoji: json['emoji'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

class ActiveDebtSummary extends Equatable {
  final String id;
  final String name;
  final double totalAmount;
  final double? monthlyPayment;

  const ActiveDebtSummary({
    required this.id,
    required this.name,
    required this.totalAmount,
    this.monthlyPayment,
  });

  factory ActiveDebtSummary.fromJson(Map<String, dynamic> json) {
    return ActiveDebtSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      monthlyPayment: json['monthly_payment'] != null
          ? (json['monthly_payment'] as num).toDouble()
          : null,
    );
  }

  @override
  List<Object?> get props => [id, name, totalAmount];
}

class CategoryBreakdown extends Equatable {
  final String name;
  final double amount;
  final int txCount;

  const CategoryBreakdown({
    required this.name,
    required this.amount,
    required this.txCount,
  });

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdown(
      name: json['effective_category'] as String? ?? 'Sin categoría',
      amount: (json['total'] as num?)?.toDouble() ?? 0,
      txCount: (json['tx_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [name, amount, txCount];
}
