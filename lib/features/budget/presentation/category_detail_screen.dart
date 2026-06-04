import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../domain/expense.dart';

class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryEmoji,
    required this.budgeted,
    required this.spent,
  });

  final String categoryId;
  final String categoryName;
  final String categoryEmoji;
  final double budgeted;
  final double spent;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  List<Expense> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      final all = await ref.read(budgetRepositoryProvider).getExpenses();
      final filtered = all
          .where((e) => e.categoryId == widget.categoryId)
          .toList()
        ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
      if (mounted) {
        setState(() {
          _expenses = filtered;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    try {
      await ref.read(budgetRepositoryProvider).deleteExpense(expense.id);
      ref.invalidate(budgetSummaryProvider);
      if (mounted) {
        setState(() => _expenses.removeWhere((e) => e.id == expense.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final fmt = NumberFormat('#,##0', 'es_MX');
    final pct = (widget.budgeted > 0)
        ? (widget.spent / widget.budgeted).clamp(0.0, 1.0)
        : 0.0;
    final percentage =
        widget.budgeted > 0 ? (widget.spent / widget.budgeted * 100) : 0.0;

    Color barColor;
    if (percentage < 60) {
      barColor = NColors.success;
    } else if (percentage < 80) {
      barColor = NColors.amber;
    } else if (percentage < 100) {
      barColor = NColors.amber;
    } else {
      barColor = NColors.error;
    }

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: NSpacing.sp4, vertical: NSpacing.sp4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_rounded,
                          color: ct.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      widget.categoryEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: NSpacing.sp3),
                    Expanded(
                      child: Text(
                        widget.categoryName,
                        style:
                            NTypography.title.copyWith(color: ct.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
                child: NGlassCard(
                  variant: NGlassVariant.featured,
                  padding: const EdgeInsets.all(NSpacing.sp5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GASTADO',
                                style: NTypography.overline
                                    .copyWith(color: ct.textTertiary),
                              ),
                              const SizedBox(height: NSpacing.sp1),
                              Text(
                                '\$${fmt.format(widget.spent)}',
                                style: NTypography.numericMd
                                    .copyWith(color: ct.textPrimary),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'PRESUPUESTADO',
                                style: NTypography.overline
                                    .copyWith(color: ct.textTertiary),
                              ),
                              const SizedBox(height: NSpacing.sp1),
                              Text(
                                '\$${fmt.format(widget.budgeted)}',
                                style: NTypography.title
                                    .copyWith(color: ct.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: NSpacing.sp4),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(NSpacing.rFull),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: ct.surface2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                      const SizedBox(height: NSpacing.sp2),
                      Text(
                        '${percentage.toStringAsFixed(1)}% utilizado',
                        style: NTypography.caption.copyWith(
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NSpacing.sp5),
              // Expenses header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
                child: Text(
                  'GASTOS',
                  style: NTypography.overline.copyWith(color: ct.textTertiary),
                ),
              ),
              const SizedBox(height: NSpacing.sp3),
              // Expense list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _expenses.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_rounded,
                                  size: 40,
                                  color: ct.textTertiary,
                                ),
                                const SizedBox(height: NSpacing.sp3),
                                Text(
                                  'Sin gastos registrados',
                                  style: NTypography.body
                                      .copyWith(color: ct.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: NSpacing.pageH),
                            itemCount: _expenses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: NSpacing.sp3),
                            itemBuilder: (context, index) {
                              final expense = _expenses[index];
                              return Dismissible(
                                key: Key(expense.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(
                                      right: NSpacing.sp5),
                                  decoration: BoxDecoration(
                                    color: NColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                        NSpacing.rXl),
                                  ),
                                  child: const Icon(
                                    Icons.delete_rounded,
                                    color: NColors.error,
                                  ),
                                ),
                                confirmDismiss: (_) async {
                                  return await _confirmDelete(context, ct);
                                },
                                onDismissed: (_) =>
                                    _deleteExpense(expense),
                                child: _ExpenseTile(
                                    expense: expense, ct: ct),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(
      BuildContext context, NColorTheme ct) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ct.bg,
        title: Text(
          'Eliminar gasto',
          style: NTypography.title.copyWith(color: ct.textPrimary),
        ),
        content: Text(
          '¿Estás seguro de que quieres eliminar este gasto?',
          style: NTypography.body.copyWith(color: ct.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: NTypography.button.copyWith(color: ct.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Eliminar',
              style: NTypography.button.copyWith(color: NColors.error),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ─── Expense Tile ─────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.ct});

  final Expense expense;
  final NColorTheme ct;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_MX');
    final dateFmt = DateFormat('d MMM', 'es');

    return NGlassCard(
      padding: const EdgeInsets.symmetric(
          horizontal: NSpacing.sp4, vertical: NSpacing.sp3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description ?? 'Sin descripción',
                  style: NTypography.title.copyWith(color: ct.textPrimary),
                ),
                if (expense.subcategory != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    expense.subcategory!,
                    style:
                        NTypography.caption.copyWith(color: ct.textTertiary),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  dateFmt.format(expense.expenseDate),
                  style: NTypography.caption.copyWith(color: ct.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            '\$${fmt.format(expense.amount)}',
            style: NTypography.title.copyWith(color: ct.textPrimary),
          ),
        ],
      ),
    );
  }
}
