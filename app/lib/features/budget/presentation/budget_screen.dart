import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../domain/budget_summary.dart';
import '../domain/expense.dart';
import 'budget_setup_screen.dart';
import 'add_expense_sheet.dart';
import 'category_detail_screen.dart';
import 'scan_receipt_action.dart';

void _refreshAll(WidgetRef ref) {
  ref.invalidate(budgetSummaryProvider);
  ref.invalidate(expensesProvider);
}

void _openExpenseSheet(BuildContext context, WidgetRef ref, {Expense? expense}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddExpenseSheet(
      expense: expense,
      onSaved: () => _refreshAll(ref),
    ),
  );
}

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    final summaryAsync = ref.watch(budgetSummaryProvider);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const _NoBudgetState(),
          data: (summary) {
            if (summary == null) {
              return const _NoBudgetState();
            }
            return _ActiveState(summary: summary);
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scanReceipt',
            onPressed: () => scanReceiptAndAddExpense(context, ref),
            backgroundColor: ct.surface2,
            child: Icon(Icons.document_scanner_rounded, color: ct.accent1),
          ),
          const SizedBox(height: NSpacing.sp3),
          FloatingActionButton(
            heroTag: 'addExpense',
            onPressed: () => _openExpenseSheet(context, ref),
            backgroundColor: ct.accent1,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ─── Month Selector ─────────────────────────────────────────────────────────

class _MonthSelector extends ConsumerWidget {
  const _MonthSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    final month = ref.watch(selectedMonthProvider);
    final label = DateFormat('MMMM yyyy', 'es').format(month);
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left_rounded, color: ct.textSecondary),
          onPressed: () {
            ref.read(selectedMonthProvider.notifier).state =
                DateTime(month.year, month.month - 1);
          },
          visualDensity: VisualDensity.compact,
        ),
        Text(
          label[0].toUpperCase() + label.substring(1),
          style: NTypography.title.copyWith(color: ct.textPrimary),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right_rounded,
              color: isCurrentMonth ? ct.textDisabled : ct.textSecondary),
          onPressed: isCurrentMonth
              ? null
              : () {
                  ref.read(selectedMonthProvider.notifier).state =
                      DateTime(month.year, month.month + 1);
                },
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

// ─── Expenses List (shared) ─────────────────────────────────────────────────

List<Widget> _buildExpensesSliver(
    AsyncValue<List<Expense>> expensesAsync, NColorTheme ct, WidgetRef ref, BuildContext context) {
  return [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            NSpacing.pageH, NSpacing.sp6, NSpacing.pageH, NSpacing.sp2),
        child: Column(
          children: [
            const _MonthSelector(),
            const SizedBox(height: NSpacing.sp3),
          ],
        ),
      ),
    ),
    expensesAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(
            child: Padding(
          padding: EdgeInsets.all(NSpacing.sp8),
          child: CircularProgressIndicator(),
        )),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (expenses) {
        if (expenses.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: NSpacing.pageH, vertical: NSpacing.sp6),
              child: Column(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      size: 40, color: ct.textDisabled),
                  const SizedBox(height: NSpacing.sp3),
                  Text(
                    'Sin gastos en este mes',
                    style:
                        NTypography.caption.copyWith(color: ct.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, index) {
                if (index >= expenses.length) return null;
                final expense = expenses[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: NSpacing.sp3),
                  child: _ExpenseTile(
                    expense: expense,
                    ct: ct,
                    onTap: () => _openExpenseSheet(context, ref, expense: expense),
                  ),
                );
              },
              childCount: expenses.length,
            ),
          ),
        );
      },
    ),
    const SliverToBoxAdapter(child: SizedBox(height: NSpacing.sp16)),
  ];
}

// ─── No Budget State ────────────────────────────────────────────────────────

class _NoBudgetState extends ConsumerWidget {
  const _NoBudgetState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    final expensesAsync = ref.watch(expensesProvider);

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: NSpacing.sp5),
                  Text(
                    'Presupuesto',
                    style: NTypography.h2.copyWith(color: ct.textPrimary),
                  ),
                  const SizedBox(height: NSpacing.sp5),
                  // Setup banner
                  NGlassCard(
                    padding: const EdgeInsets.all(NSpacing.sp5),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ct.accent1.withValues(alpha: 0.12),
                          ),
                          child: Icon(Icons.account_balance_wallet_rounded,
                              size: 28, color: ct.accent1),
                        ),
                        const SizedBox(height: NSpacing.sp4),
                        Text(
                          'Configura tu presupuesto',
                          style: NTypography.title
                              .copyWith(color: ct.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: NSpacing.sp2),
                        Text(
                          'Establece un presupuesto mensual y controla tus gastos por categoria.',
                          style: NTypography.caption
                              .copyWith(color: ct.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: NSpacing.sp4),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: NColors.grad,
                              borderRadius:
                                  BorderRadius.circular(NSpacing.rFull),
                              boxShadow: const [NColors.glowIndigo],
                            ),
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const BudgetSetupScreen(),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(NSpacing.rFull),
                                ),
                              ),
                              child: Text(
                                'Comenzar',
                                style: NTypography.button
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ..._buildExpensesSliver(expensesAsync, ct, ref, context),
        ],
      ),
    );
  }
}

// ─── Expense Tile ────────────────────────────────────────────────────────────

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.ct, this.onTap});

  final Expense expense;
  final NColorTheme ct;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00', 'es_MX');
    final dateFmt = DateFormat('d MMM', 'es');

    return NGlassCard(
      padding: const EdgeInsets.all(NSpacing.sp4),
      onTap: onTap,
      child: Row(
        children: [
          Text(expense.categoryEmoji ?? '',
              style: const TextStyle(fontSize: 20)),
          const SizedBox(width: NSpacing.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description ?? expense.categoryName ?? 'Gasto',
                  style: NTypography.title.copyWith(color: ct.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${expense.categoryName ?? ''} · ${dateFmt.format(expense.expenseDate)}',
                  style: NTypography.caption.copyWith(color: ct.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            '-\$${fmt.format(expense.amount)}',
            style: NTypography.title.copyWith(color: NColors.error),
          ),
        ],
      ),
    );
  }
}

// ─── Active State ─────────────────────────────────────────────────────────────

class _ActiveState extends ConsumerWidget {
  const _ActiveState({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    final expensesAsync = ref.watch(expensesProvider);
    final sortedCategories = [...summary.categories]
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    final cycleStart = DateTime.parse(summary.cycle.start);
    final cycleEnd = DateTime.parse(summary.cycle.end);
    final cycleFmt = DateFormat('d MMM', 'es');
    final cycleLabel =
        '${cycleFmt.format(cycleStart)} — ${cycleFmt.format(cycleEnd)}';
    final remaining = summary.cycle.remainingDays;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: NSpacing.sp5),
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Presupuesto',
                        style:
                            NTypography.h2.copyWith(color: ct.textPrimary),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings_rounded,
                            color: ct.textSecondary),
                        onPressed: () {
                          Navigator.of(context)
                              .push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const BudgetSetupScreen(isEdit: true),
                            ),
                          )
                              .then((_) => _refreshAll(ref));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: NSpacing.sp2),
                  // Cycle info bar
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 14, color: ct.textTertiary),
                      const SizedBox(width: NSpacing.sp2),
                      Text(
                        cycleLabel,
                        style: NTypography.caption
                            .copyWith(color: ct.textSecondary),
                      ),
                      const SizedBox(width: NSpacing.sp3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: NSpacing.sp2, vertical: 2),
                        decoration: BoxDecoration(
                          color: ct.accent1.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(NSpacing.rFull),
                        ),
                        child: Text(
                          '$remaining dias restantes',
                          style: NTypography.overline
                              .copyWith(color: ct.accent1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NSpacing.sp6),
                  // Circular progress ring
                  Center(
                    child: _CircularProgressRing(
                      percentage: summary.global.percentage,
                      spent: summary.global.spent,
                      budgeted: summary.global.budgeted,
                      ct: ct,
                    ),
                  ),
                  const SizedBox(height: NSpacing.sp6),
                ],
              ),
            ),
          ),
        ),
        // Category list
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= sortedCategories.length) return null;
                final cat = sortedCategories[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: NSpacing.sp3),
                  child: NGlassCard(
                    padding: const EdgeInsets.all(NSpacing.sp4),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CategoryDetailScreen(
                            categoryId: cat.categoryId,
                            categoryName: cat.name,
                            categoryEmoji: cat.emoji,
                            budgeted: cat.budgeted,
                            spent: cat.spent,
                          ),
                        ),
                      );
                    },
                    child: _CategoryTile(cat: cat, ct: ct),
                  ),
                );
              },
              childCount: sortedCategories.length,
            ),
          ),
        ),
        ..._buildExpensesSliver(expensesAsync, ct, ref, context),
      ],
    );
  }
}

// ─── Circular Progress Ring ───────────────────────────────────────────────────

class _CircularProgressRing extends StatelessWidget {
  const _CircularProgressRing({
    required this.percentage,
    required this.spent,
    required this.budgeted,
    required this.ct,
  });

  final double percentage;
  final double spent;
  final double budgeted;
  final NColorTheme ct;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_MX');
    final pct = (percentage / 100).clamp(0.0, 1.0);

    Color ringColor;
    if (percentage < 60) {
      ringColor = NColors.success;
    } else if (percentage < 80) {
      ringColor = NColors.amber;
    } else if (percentage < 100) {
      ringColor = NColors.amber;
    } else {
      ringColor = NColors.error;
    }

    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(200, 200),
            painter: _RingPainter(
              progress: pct,
              ringColor: ringColor,
              trackColor: ct.surface2,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style:
                    NTypography.numericMd.copyWith(color: ct.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                '\$${fmt.format(spent)}',
                style: NTypography.title.copyWith(color: ct.textPrimary),
              ),
              Text(
                'de \$${fmt.format(budgeted)}',
                style:
                    NTypography.caption.copyWith(color: ct.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
  });

  final double progress;
  final Color ringColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 14.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(rect, startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.ringColor != ringColor;
}

// ─── Category Tile ────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.cat, required this.ct});

  final CategoryBudgetSummary cat;
  final NColorTheme ct;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'es_MX');
    final pct = (cat.percentage / 100).clamp(0.0, 1.0);

    Color barColor;
    if (cat.percentage < 60) {
      barColor = NColors.success;
    } else if (cat.percentage < 80) {
      barColor = NColors.amber;
    } else if (cat.percentage < 100) {
      barColor = NColors.amber;
    } else {
      barColor = NColors.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(cat.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: NSpacing.sp3),
            Expanded(
              child: Text(
                cat.name,
                style: NTypography.title.copyWith(color: ct.textPrimary),
              ),
            ),
            Text(
              '\$${fmt.format(cat.spent)} / \$${fmt.format(cat.budgeted)}',
              style:
                  NTypography.caption.copyWith(color: ct.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: NSpacing.sp2),
        ClipRRect(
          borderRadius: BorderRadius.circular(NSpacing.rFull),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: ct.surface2,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}
