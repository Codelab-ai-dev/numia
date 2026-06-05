import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/widgets/n_badge.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../../investments/domain/investment.dart';
import '../../investments/presentation/add_investment_sheet.dart';

// Stable palette for avatar tints, chosen by investment type.
const _avatarPalette = [
  Color(0xFF22C55E),
  Color(0xFF6366F1),
  Color(0xFF38BDF8),
  Color(0xFF818CF8),
  Color(0xFFF59E0B),
  Color(0xFFEC4899),
];

Color _colorForType(String type) =>
    _avatarPalette[type.hashCode.abs() % _avatarPalette.length];

void _openInvestmentSheet(BuildContext context, WidgetRef ref,
    {Investment? investment}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddInvestmentSheet(
      investment: investment,
      onSaved: () => ref.invalidate(investmentsProvider),
    ),
  );
}

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _selectedFilter = 'Todo';

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final investmentsAsync = ref.watch(investmentsProvider);

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
                child: Text('Inversiones',
                    style: NTypography.h1.copyWith(color: ct.textPrimary)),
              ),
              const SizedBox(height: NSpacing.sp5),

              Expanded(
                child: investmentsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorState(
                    onRetry: () => ref.invalidate(investmentsProvider),
                  ),
                  data: (investments) {
                    if (investments.isEmpty) {
                      return const _EmptyState();
                    }
                    return _LoadedView(
                      investments: investments,
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
        onPressed: () => _openInvestmentSheet(context, ref),
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
    required this.investments,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final List<Investment> investments;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Distinct types preserving insertion order, with "Todo" first.
    final types = <String>['Todo'];
    for (final inv in investments) {
      if (!types.contains(inv.type)) types.add(inv.type);
    }
    final effectiveFilter =
        types.contains(selectedFilter) ? selectedFilter : 'Todo';
    final visible = effectiveFilter == 'Todo'
        ? investments
        : investments.where((i) => i.type == effectiveFilter).toList();

    final totalInvested =
        investments.fold<double>(0, (sum, i) => sum + i.amountInvested);
    final totalCurrent =
        investments.fold<double>(0, (sum, i) => sum + i.currentValue);
    final rendimiento = totalInvested > 0
        ? ((totalCurrent - totalInvested) / totalInvested) * 100
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter chips — glass pills ──
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
            itemCount: types.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: NSpacing.sp2),
            itemBuilder: (context, i) => _FilterChip(
              label: types[i],
              selected: effectiveFilter == types[i],
              onTap: () => onFilterChanged(types[i]),
            ),
          ),
        ),
        const SizedBox(height: NSpacing.sp5),

        // ── Investment list — glass cards ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(investmentsProvider),
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
              itemCount: visible.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: NSpacing.sp3),
              itemBuilder: (context, i) => _InvestmentRow(
                investment: visible[i],
                onTap: () => _openInvestmentSheet(context, ref,
                    investment: visible[i]),
              ),
            ),
          ),
        ),

        // ── Bottom summary bar — glass ──
        _SummaryBar(totalInvested: totalInvested, rendimiento: rendimiento),
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
            Icon(Icons.trending_up_rounded,
                size: 48, color: ct.textTertiary),
            const SizedBox(height: NSpacing.sp4),
            Text(
              'Aún no tienes inversiones',
              style: NTypography.title.copyWith(color: ct.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NSpacing.sp2),
            Text(
              'Agrega tu primera inversión con el botón +',
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
              'No pudimos cargar tus inversiones',
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
// Investment row — glass card
// ─────────────────────────────────────────────
class _InvestmentRow extends StatelessWidget {
  const _InvestmentRow({required this.investment, required this.onTap});
  final Investment investment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final color = _colorForType(investment.type);
    final pct = investment.returnPct;
    final isPositive = pct >= 0;
    final subtitle = investment.institution?.isNotEmpty == true
        ? '${investment.type} · ${investment.institution}'
        : investment.type;

    return NGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: NSpacing.sp5,
        vertical: NSpacing.sp4,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                investment.name.isNotEmpty
                    ? investment.name[0].toUpperCase()
                    : '?',
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: NSpacing.sp3),

          // Name + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(investment.name,
                    style:
                        NTypography.title.copyWith(color: ct.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NTypography.caption.copyWith(
                    color: ct.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: NSpacing.sp3),

          // Current value + return
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatMXN(investment.currentValue),
                style: NTypography.title.copyWith(color: ct.textPrimary),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isPositive ? '\u2197' : '\u2198',
                    style: TextStyle(
                      fontSize: 12,
                      color: isPositive ? NColors.success : NColors.error,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${isPositive ? '+' : ''}${CurrencyFormatter.formatPct(pct)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? NColors.success : NColors.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom summary bar — glass
// ─────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.totalInvested, required this.rendimiento});
  final double totalInvested;
  final double rendimiento;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final isPositive = rendimiento >= 0;

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
              // Total invertido
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TOTAL INVERTIDO',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp1),
                  Text(
                    CurrencyFormatter.formatMXN(totalInvested),
                    style: NTypography.numericLg
                        .copyWith(color: ct.textPrimary),
                  ),
                ],
              ),

              // Rendimiento badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('RENDIMIENTO',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp1),
                  NBadge(
                    label:
                        '${isPositive ? '+' : ''}${CurrencyFormatter.formatPct(rendimiento)}',
                    variant: isPositive
                        ? NBadgeVariant.success
                        : NBadgeVariant.error,
                    icon: isPositive ? '\u2197' : '\u2198',
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
