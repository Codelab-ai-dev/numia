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
import '../../dashboard/domain/debt.dart';
import 'add_debt_sheet.dart';

void _openDebtSheet(BuildContext context, WidgetRef ref, {Debt? debt}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddDebtSheet(
      debt: debt,
      onSaved: () {
        ref.invalidate(debtsProvider);
        ref.invalidate(dashboardSummaryProvider);
      },
    ),
  );
}

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  String _selectedFilter = 'Todo';

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final debtsAsync = ref.watch(debtsProvider);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  NSpacing.pageH, NSpacing.sp5, NSpacing.pageH, 0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: ct.textPrimary),
                    ),
                    const SizedBox(width: NSpacing.sp2),
                    Text('Deudas',
                        style:
                            NTypography.h1.copyWith(color: ct.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: NSpacing.sp5),

              Expanded(
                child: debtsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorState(
                    onRetry: () => ref.invalidate(debtsProvider),
                  ),
                  data: (debts) {
                    if (debts.isEmpty) {
                      return const _EmptyState();
                    }
                    return _LoadedView(
                      debts: debts,
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
        onPressed: () => _openDebtSheet(context, ref),
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
    required this.debts,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final List<Debt> debts;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = <String>['Todo'];
    for (final d in debts) {
      if (!types.contains(d.type)) types.add(d.type);
    }
    final effectiveFilter =
        types.contains(selectedFilter) ? selectedFilter : 'Todo';
    final visible = effectiveFilter == 'Todo'
        ? debts
        : debts.where((d) => d.type == effectiveFilter).toList();

    final totalDebt = debts.fold<double>(0, (sum, d) => sum + d.totalAmount);
    final totalPayment =
        debts.fold<double>(0, (sum, d) => sum + (d.monthlyPayment ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter chips ──
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
            itemCount: types.length,
            separatorBuilder: (_, __) => const SizedBox(width: NSpacing.sp2),
            itemBuilder: (context, i) => _FilterChip(
              label: types[i],
              selected: effectiveFilter == types[i],
              onTap: () => onFilterChanged(types[i]),
            ),
          ),
        ),
        const SizedBox(height: NSpacing.sp5),

        // ── Debt list ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(debtsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
              itemCount: visible.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: NSpacing.sp3),
              itemBuilder: (context, i) => _DebtRow(
                debt: visible[i],
                onTap: () => _openDebtSheet(context, ref, debt: visible[i]),
              ),
            ),
          ),
        ),

        // ── Bottom summary bar ──
        _SummaryBar(totalDebt: totalDebt, totalPayment: totalPayment),
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
            Icon(Icons.credit_card_off_rounded,
                size: 48, color: ct.textTertiary),
            const SizedBox(height: NSpacing.sp4),
            Text(
              'Aún no tienes deudas',
              style: NTypography.title.copyWith(color: ct.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NSpacing.sp2),
            Text(
              'Agrega tu primera deuda con el botón +',
              style: NTypography.body.copyWith(color: ct.textSecondary),
              textAlign: TextAlign.center,
            ),
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
            Text(
              'No pudimos cargar tus deudas',
              style: NTypography.title.copyWith(color: ct.textPrimary),
              textAlign: TextAlign.center,
            ),
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
// Debt row — glass card
// ─────────────────────────────────────────────
class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt, required this.onTap});
  final Debt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final paidPct = debt.paidPercentage;
    final showProgress = debt.originalAmount != null && debt.originalAmount! > 0;
    final subtitle = debt.institution?.isNotEmpty == true
        ? '${debt.type} · ${debt.institution}'
        : debt.type;

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
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(debt.name,
                        style: NTypography.title
                            .copyWith(color: ct.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NTypography.caption
                          .copyWith(color: ct.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NSpacing.sp3),

              // Current balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatMXN(debt.totalAmount),
                    style:
                        NTypography.title.copyWith(color: ct.textPrimary),
                  ),
                  if (debt.interestRate != null && debt.interestRate! > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${CurrencyFormatter.formatPct(debt.interestRate!)} interés',
                      style: NTypography.caption
                          .copyWith(color: ct.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Paid progress bar
          if (showProgress) ...[
            const SizedBox(height: NSpacing.sp3),
            ClipRRect(
              borderRadius: BorderRadius.circular(NSpacing.rFull),
              child: LinearProgressIndicator(
                value: paidPct,
                minHeight: 6,
                backgroundColor: ct.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(ct.accent1),
              ),
            ),
            const SizedBox(height: NSpacing.sp2),
            Text(
              '${CurrencyFormatter.formatPct(paidPct * 100)} pagado',
              style: NTypography.caption.copyWith(color: ct.textTertiary),
            ),
          ],

          // Monthly payment
          if (debt.monthlyPayment != null && debt.monthlyPayment! > 0) ...[
            const SizedBox(height: NSpacing.sp2),
            Text(
              'Pago mensual ${CurrencyFormatter.formatMXN(debt.monthlyPayment!)}',
              style: NTypography.caption.copyWith(
                color: NColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom summary bar — glass
// ─────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.totalDebt, required this.totalPayment});
  final double totalDebt;
  final double totalPayment;

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
                  Text('DEUDA TOTAL',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp1),
                  Text(
                    CurrencyFormatter.formatMXN(totalDebt),
                    style: NTypography.numericLg
                        .copyWith(color: ct.textPrimary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('PAGO MENSUAL',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp1),
                  Text(
                    CurrencyFormatter.formatMXN(totalPayment),
                    style: NTypography.numericLg
                        .copyWith(color: NColors.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
