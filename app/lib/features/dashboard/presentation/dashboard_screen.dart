import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/widgets/n_badge.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../../../shared/widgets/n_gradient_text.dart';
import '../domain/financial_summary.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final insightAsync = ref.watch(coachInsightProvider);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardSummaryProvider);
              ref.invalidate(coachInsightProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Header: logo + avatar ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NSpacing.pageH, NSpacing.sp5, NSpacing.pageH, 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        NGradientText('numia', style: NTypography.logo),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: NColors.grad,
                            boxShadow: [NColors.glowIndigo],
                          ),
                          child: Center(
                            child: Text(
                              profile != null ? _initials(profile.fullName) : '',
                              style: NTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: NSpacing.sp6)),

                // ── Body: depends on summary load state ──
                summaryAsync.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: NSpacing.sp10),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        NSpacing.pageH, NSpacing.sp10, NSpacing.pageH, 0,
                      ),
                      child: Text(
                        'No pudimos cargar tu resumen financiero.',
                        style: NTypography.body
                            .copyWith(color: ct.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  data: (summary) => SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Patrimonio Neto ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: NSpacing.pageH),
                        child: _PatrimonioCard(
                          netWorth: summary.netWorth,
                          monthNet: summary.monthNet,
                        ),
                      ),
                      const SizedBox(height: NSpacing.sp4),

                      // ── Meta activa + Deuda row ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: NSpacing.pageH),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _GoalMiniCard(
                                  goal: summary.activeGoals.isNotEmpty
                                      ? summary.activeGoals.first
                                      : null,
                                ),
                              ),
                              const SizedBox(width: NSpacing.sp3),
                              Expanded(
                                child: _DebtMiniCard(
                                  debts: summary.activeDebts,
                                  totalDebt: summary.totalDebt,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: NSpacing.sp4),

                      // ── Insight IA ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: NSpacing.pageH),
                        child: _InsightCard(insight: insightAsync),
                      ),
                      const SizedBox(height: NSpacing.sp10),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Patrimonio Card (featured glass) con mini sparkline
// ─────────────────────────────────────────────
class _PatrimonioCard extends StatelessWidget {
  const _PatrimonioCard({required this.netWorth, required this.monthNet});
  final double netWorth;
  final double monthNet;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final isPositive = monthNet >= 0;

    return NGlassCard(
      variant: NGlassVariant.featured,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PATRIMONIO NETO', style: NTypography.overline.copyWith(color: ct.textTertiary)),
          const SizedBox(height: NSpacing.sp3),

          // Net worth amount
          NGradientText(
            CurrencyFormatter.formatMXN(netWorth),
            style: NTypography.numericLg,
          ),

          const SizedBox(height: NSpacing.sp3),

          // Month net flow
          Row(
            children: [
              NBadge(
                label: CurrencyFormatter.formatDelta(monthNet),
                variant: isPositive
                    ? NBadgeVariant.emerald
                    : NBadgeVariant.error,
                icon: isPositive ? '\u2197' : '\u2198',
              ),
              const SizedBox(width: NSpacing.sp2),
              Text('este mes',
                  style: NTypography.caption
                      .copyWith(color: ct.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Meta activa mini card
// ─────────────────────────────────────────────
class _GoalMiniCard extends StatelessWidget {
  const _GoalMiniCard({required this.goal});
  final ActiveGoalSummary? goal;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return NGlassCard(
      padding: const EdgeInsets.all(NSpacing.sp5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_rounded, size: 18, color: ct.accent1),
              const SizedBox(width: NSpacing.sp2),
              Flexible(
                child: Text('META ACTIVA', style: NTypography.overline.copyWith(color: ct.textTertiary), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: NSpacing.sp2),
          if (goal == null)
            Text('Sin metas activas',
                style: NTypography.body.copyWith(color: ct.textSecondary))
          else
            _GoalProgress(goal: goal!),
        ],
      ),
    );
  }
}

class _GoalProgress extends StatelessWidget {
  const _GoalProgress({required this.goal});
  final ActiveGoalSummary goal;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final pct = goal.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(goal.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: NTypography.title.copyWith(color: ct.textPrimary)),
        const SizedBox(height: NSpacing.sp3),

        // Progress bar indigo -> emerald
        ClipRRect(
          borderRadius: BorderRadius.circular(NSpacing.rFull),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: ct.surface3,
                    borderRadius: BorderRadius.circular(NSpacing.rFull),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: NColors.gradH,
                      borderRadius: BorderRadius.circular(NSpacing.rFull),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: NSpacing.sp2),
        Row(
          children: [
            Text(
              '${(pct * 100).toInt()}%',
              style: NTypography.caption.copyWith(
                color: ct.accent1,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: NSpacing.sp2),
            Flexible(
              child: Text(
                '\$${(goal.currentAmount / 1000).toInt()}k/\$${(goal.targetAmount / 1000).toInt()}k',
                style: NTypography.caption.copyWith(color: ct.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Deuda mini card
// ─────────────────────────────────────────────
class _DebtMiniCard extends StatelessWidget {
  const _DebtMiniCard({required this.debts, required this.totalDebt});
  final List<ActiveDebtSummary> debts;
  final double totalDebt;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final monthlyPayment = debts.fold<double>(
        0, (sum, d) => sum + (d.monthlyPayment ?? 0));

    return NGlassCard(
      padding: const EdgeInsets.all(NSpacing.sp5),
      onTap: () => context.push('/debts'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card_rounded, size: 18, color: ct.accent3),
              const SizedBox(width: NSpacing.sp2),
              Text('DEUDA', style: NTypography.overline.copyWith(color: ct.textTertiary)),
            ],
          ),
          const SizedBox(height: NSpacing.sp2),
          if (debts.isEmpty)
            Text('Sin deudas activas',
                style: NTypography.body.copyWith(color: ct.textSecondary))
          else ...[
            Text(
              CurrencyFormatter.formatMXN(totalDebt),
              style: NTypography.numericMd.copyWith(color: ct.textPrimary),
            ),
            const SizedBox(height: NSpacing.sp3),
            Text(
              debts.length == 1 ? '1 deuda activa' : '${debts.length} deudas activas',
              style: NTypography.caption.copyWith(color: ct.textSecondary),
            ),
            if (monthlyPayment > 0) ...[
              const SizedBox(height: NSpacing.sp1),
              Text(
                'Pago mensual ${CurrencyFormatter.formatMXN(monthlyPayment)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NTypography.caption.copyWith(
                  color: NColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Insight IA card
// ─────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});
  final AsyncValue<String> insight;

  static const _fallback =
      'Registra tus cuentas, metas y deudas para recibir consejos personalizados.';

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final isLoading = insight.isLoading;
    final text = insight.maybeWhen(
      data: (t) => t.trim().isEmpty ? _fallback : t,
      orElse: () => _fallback,
    );

    return NGlassCard(
      variant: NGlassVariant.accent,
      accentColor: ct.accent2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'INSIGHT IA',
                style: NTypography.overline.copyWith(color: ct.accent2),
              ),
              Text(
                '  \u00B7  HOY',
                style: NTypography.overline.copyWith(color: ct.accent2),
              ),
            ],
          ),
          const SizedBox(height: NSpacing.sp3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: ct.accent2,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: ct.accent2.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NSpacing.sp3),
              Expanded(
                child: isLoading
                    ? Text(
                        'Generando tu insight de hoy…',
                        style: NTypography.body
                            .copyWith(color: ct.textTertiary),
                      )
                    : Text(text,
                        style: NTypography.body
                            .copyWith(color: ct.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
