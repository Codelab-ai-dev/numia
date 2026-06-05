import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../domain/goal.dart';
import 'add_goal_sheet.dart';
import 'contribute_sheet.dart';
import 'goal_types.dart';

void _refreshGoals(WidgetRef ref) {
  ref.invalidate(allGoalsProvider);
  ref.invalidate(goalsProvider);
  ref.invalidate(dashboardSummaryProvider);
}

void _openGoalSheet(BuildContext context, WidgetRef ref, {Goal? goal}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddGoalSheet(
      goal: goal,
      onSaved: () => _refreshGoals(ref),
    ),
  );
}

void _openContributeSheet(BuildContext context, WidgetRef ref, Goal goal) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ContributeSheet(
      goal: goal,
      onSaved: () => _refreshGoals(ref),
    ),
  );
}

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  String _selectedFilter = 'Activas';

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final goalsAsync = ref.watch(allGoalsProvider);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NSpacing.pageH, NSpacing.sp5, NSpacing.pageH, 0,
                ),
                child: Text('Metas',
                    style: NTypography.h1.copyWith(color: ct.textPrimary)),
              ),
              const SizedBox(height: NSpacing.sp5),
              Expanded(
                child: goalsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorState(
                    onRetry: () => ref.invalidate(allGoalsProvider),
                  ),
                  data: (goals) {
                    if (goals.isEmpty) {
                      return const _EmptyState();
                    }
                    return _LoadedView(
                      goals: goals,
                      selectedFilter: _selectedFilter,
                      onFilterChanged: (f) =>
                          setState(() => _selectedFilter = f),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openGoalSheet(context, ref),
        backgroundColor: ct.accent1,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Loaded view — filters, list and summary
// ─────────────────────────────────────────────
class _LoadedView extends ConsumerWidget {
  const _LoadedView({
    required this.goals,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final List<Goal> goals;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  static const _filters = ['Activas', 'Completadas', 'Todas'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    final visible = switch (selectedFilter) {
      'Activas' => goals.where((g) => g.status == 'active').toList(),
      'Completadas' => goals.where((g) => g.status == 'completed').toList(),
      _ => goals,
    };

    final totalSaved =
        visible.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final totalTarget =
        visible.fold<double>(0, (sum, g) => sum + g.targetAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: NSpacing.sp2),
            itemBuilder: (context, i) => _FilterChip(
              label: _filters[i],
              selected: selectedFilter == _filters[i],
              onTap: () => onFilterChanged(_filters[i]),
            ),
          ),
        ),
        const SizedBox(height: NSpacing.sp5),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(allGoalsProvider),
            child: visible.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: NSpacing.sp10),
                      Center(
                        child: Text(
                          'Sin metas en este filtro',
                          style: NTypography.body
                              .copyWith(color: ct.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: NSpacing.pageH),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: NSpacing.sp3),
                    itemBuilder: (context, i) => _GoalRow(
                      goal: visible[i],
                      onTap: () =>
                          _openGoalSheet(context, ref, goal: visible[i]),
                      onContribute: () =>
                          _openContributeSheet(context, ref, visible[i]),
                    ),
                  ),
          ),
        ),
        _SummaryBar(totalSaved: totalSaved, totalTarget: totalTarget),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Empty + error states
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, size: 48, color: ct.textTertiary),
            const SizedBox(height: NSpacing.sp4),
            Text('Aún no tienes metas',
                style: NTypography.title.copyWith(color: ct.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: NSpacing.sp2),
            Text('Crea tu primera meta con el botón +',
                style: NTypography.body.copyWith(color: ct.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: ct.textTertiary),
            const SizedBox(height: NSpacing.sp4),
            Text('No pudimos cargar tus metas',
                style: NTypography.title.copyWith(color: ct.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: NSpacing.sp4),
            TextButton(
              onPressed: onRetry,
              child: Text('Reintentar',
                  style: NTypography.button.copyWith(color: ct.accent1)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Filter chip — glass pill
// ─────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NSpacing.rFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
              horizontal: NSpacing.sp4,
              vertical: NSpacing.sp2,
            ),
            decoration: BoxDecoration(
              gradient: selected ? NColors.grad : null,
              color: selected ? null : ct.surface2,
              borderRadius: BorderRadius.circular(NSpacing.rFull),
              border: Border.all(
                color: selected ? Colors.transparent : ct.borderSubtle,
              ),
              boxShadow: selected
                  ? [BoxShadow(color: NColors.indigo.withValues(alpha: 0.3), blurRadius: 8)]
                  : null,
            ),
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : ct.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Goal row — glass card
// ─────────────────────────────────────────────
class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.onTap,
    required this.onContribute,
  });
  final Goal goal;
  final VoidCallback onTap;
  final VoidCallback onContribute;

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final months = (date.year - now.year) * 12 + (date.month - now.month);
    if (months <= 0) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
    return 'faltan $months ${months == 1 ? 'mes' : 'meses'}';
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final type = goalTypeFor(goal.type);
    final pct = goal.progress;
    final isCompleted = goal.status == 'completed';

    return NGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: NSpacing.sp5,
        vertical: NSpacing.sp4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(goal.emoji ?? type.emoji,
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: NSpacing.sp3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(goal.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            NTypography.title.copyWith(color: ct.textPrimary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _PriorityBadge(priority: goal.priority),
                        if (isCompleted) ...[
                          const SizedBox(width: NSpacing.sp2),
                          const _CompletedBadge(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NSpacing.sp3),
              Text('${(pct * 100).toInt()}%',
                  style: NTypography.title.copyWith(color: ct.accent1)),
            ],
          ),
          const SizedBox(height: NSpacing.sp3),
          ClipRRect(
            borderRadius: BorderRadius.circular(NSpacing.rFull),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: ct.surface2,
              valueColor: AlwaysStoppedAnimation<Color>(ct.accent1),
            ),
          ),
          const SizedBox(height: NSpacing.sp2),
          Row(
            children: [
              Text(
                '${CurrencyFormatter.formatMXN(goal.currentAmount)} / ${CurrencyFormatter.formatMXN(goal.targetAmount)}',
                style: NTypography.caption.copyWith(color: ct.textTertiary),
              ),
              const Spacer(),
              if (goal.targetDate != null)
                Text(_dateLabel(goal.targetDate!),
                    style:
                        NTypography.caption.copyWith(color: ct.textTertiary)),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: NSpacing.sp3),
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onContribute,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: NSpacing.sp4, vertical: NSpacing.sp2),
                  decoration: BoxDecoration(
                    color: ct.accent1.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(NSpacing.rFull),
                    border: Border.all(color: ct.accent1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: ct.accent1),
                      const SizedBox(width: NSpacing.sp1),
                      Text('Abonar',
                          style: NTypography.caption.copyWith(
                            color: ct.accent1,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});
  final int priority;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final (label, color) = switch (priority) {
      3 => ('Alta', NColors.error),
      2 => ('Media', ct.accent1),
      _ => ('Baja', ct.textTertiary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NSpacing.sp2, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(NSpacing.rFull),
      ),
      child: Text(label, style: NTypography.overline.copyWith(color: color)),
    );
  }
}

class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: NSpacing.sp2, vertical: 1),
      decoration: BoxDecoration(
        color: ct.accent2.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(NSpacing.rFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 12, color: ct.accent2),
          const SizedBox(width: 2),
          Text('Lograda',
              style: NTypography.overline.copyWith(color: ct.accent2)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom summary bar — glass
// ─────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.totalSaved, required this.totalTarget});
  final double totalSaved;
  final double totalTarget;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: ct.glassBlur / 2,
          sigmaY: ct.glassBlur / 2,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            NSpacing.pageH, NSpacing.sp4, NSpacing.pageH, NSpacing.sp4,
          ),
          decoration: BoxDecoration(
            color: ct.surface1,
            border: Border(top: BorderSide(color: ct.borderSubtle)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TOTAL AHORRADO',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp1),
                  Text(CurrencyFormatter.formatMXN(totalSaved),
                      style: NTypography.numericLg
                          .copyWith(color: ct.accent2)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TOTAL OBJETIVO',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp1),
                  Text(CurrencyFormatter.formatMXN(totalTarget),
                      style: NTypography.numericLg
                          .copyWith(color: ct.textPrimary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
