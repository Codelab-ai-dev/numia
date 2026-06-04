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
import 'budget_setup_screen.dart';
import 'add_expense_sheet.dart';
import 'category_detail_screen.dart';

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
          error: (e, _) => _EmptyState(ct: ct),
          data: (summary) {
            if (summary == null) {
              return _EmptyState(ct: ct);
            }
            return _ActiveState(summary: summary, ct: ct, ref: ref);
          },
        ),
      ),
      floatingActionButton: summaryAsync.maybeWhen(
        data: (summary) {
          if (summary == null) return null;
          return FloatingActionButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddExpenseSheet(
                  onSaved: () => ref.invalidate(budgetSummaryProvider),
                ),
              );
            },
            backgroundColor: ct.accent1,
            child: const Icon(Icons.add, color: Colors.white),
          );
        },
        orElse: () => null,
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.ct});
  final NColorTheme ct;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ct.accent1.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.account_balance_wallet_rounded,
                  size: 40, color: ct.accent1),
            ),
            const SizedBox(height: NSpacing.sp6),
            Text(
              'Configura tu presupuesto',
              style: NTypography.h2.copyWith(color: ct.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NSpacing.sp3),
            Text(
              'Establece un presupuesto mensual y controla\ntus gastos por categoría.',
              style: NTypography.body.copyWith(color: ct.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NSpacing.sp8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: NColors.grad,
                  borderRadius: BorderRadius.circular(NSpacing.rFull),
                  boxShadow: const [NColors.glowIndigo],
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BudgetSetupScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(NSpacing.rFull),
                    ),
                  ),
                  child: Text(
                    'Comenzar',
                    style: NTypography.button.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Active State ─────────────────────────────────────────────────────────────

class _ActiveState extends StatelessWidget {
  const _ActiveState({
    required this.summary,
    required this.ct,
    required this.ref,
  });

  final BudgetSummary summary;
  final NColorTheme ct;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
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
              padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
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
                        style: NTypography.h2.copyWith(color: ct.textPrimary),
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
                              .then((_) {
                            ref.invalidate(budgetSummaryProvider);
                          });
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
                        style:
                            NTypography.caption.copyWith(color: ct.textSecondary),
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
                          '$remaining días restantes',
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
        const SliverToBoxAdapter(child: SizedBox(height: NSpacing.sp16)),
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
                style: NTypography.numericMd.copyWith(color: ct.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                '\$${fmt.format(spent)}',
                style: NTypography.title.copyWith(color: ct.textPrimary),
              ),
              Text(
                'de \$${fmt.format(budgeted)}',
                style: NTypography.caption.copyWith(color: ct.textSecondary),
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

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
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
              style: NTypography.caption.copyWith(color: ct.textSecondary),
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
