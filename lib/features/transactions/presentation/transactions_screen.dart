import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/widgets/n_badge.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  int _selectedFilter = 0;

  static const _filters = ['Todo', 'CETES', 'ETFs', 'Fondos'];

  static const _investments = [
    _Investment('CETES 28 días', 'CETES Directo', 45000, 11.2, Color(0xFF22C55E)),
    _Investment('VOO S&P 500', 'GBM+', 28400, 18.6, Color(0xFF6366F1)),
    _Investment('FUNO 11', 'Kuspit', 12800, -2.4, Color(0xFF38BDF8)),
    _Investment('Nu México', 'Cajitas · Ahorro', 8200, 9.8, Color(0xFF818CF8)),
    _Investment('Bitcoin (BTC)', 'Bitso', 15600, 24.3, Color(0xFFF59E0B)),
  ];

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

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
                child: Text('Inversiones', style: NTypography.h1.copyWith(color: ct.textPrimary)),
              ),

              const SizedBox(height: NSpacing.sp5),

              // ── Filter chips — glass pills ──
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
                  itemCount: _filters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: NSpacing.sp2),
                  itemBuilder: (context, i) => _FilterChip(
                    label: _filters[i],
                    selected: _selectedFilter == i,
                    onTap: () => setState(() => _selectedFilter = i),
                  ),
                ),
              ),

              const SizedBox(height: NSpacing.sp5),

              // ── Investment list — glass cards ──
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
                  itemCount: _investments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: NSpacing.sp3),
                  itemBuilder: (context, i) =>
                      _InvestmentRow(investment: _investments[i]),
                ),
              ),

              // ── Bottom summary bar — glass ──
              const _SummaryBar(totalInvested: 110000, rendimiento: 12.4),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Investment data model
// ─────────────────────────────────────────────
class _Investment {
  const _Investment(this.name, this.platform, this.amount, this.change, this.color);
  final String name;
  final String platform;
  final double amount;
  final double change;
  final Color color;
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
  const _InvestmentRow({required this.investment});
  final _Investment investment;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final isPositive = investment.change >= 0;

    return NGlassCard(
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
              color: investment.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                investment.name[0],
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: investment.color,
                ),
              ),
            ),
          ),

          const SizedBox(width: NSpacing.sp3),

          // Name + platform
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(investment.name, style: NTypography.title.copyWith(color: ct.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  investment.platform,
                  style: NTypography.caption.copyWith(
                    color: ct.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: NSpacing.sp3),

          // Amount + change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatMXN(investment.amount),
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
                    '${isPositive ? '+' : ''}${CurrencyFormatter.formatPct(investment.change)}',
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
                  Text('TOTAL INVERTIDO', style: NTypography.overline.copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp1),
                  Text(
                    CurrencyFormatter.formatMXN(totalInvested),
                    style: NTypography.numericLg.copyWith(color: ct.textPrimary),
                  ),
                ],
              ),

              // Rendimiento badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('RENDIMIENTO', style: NTypography.overline.copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp1),
                  NBadge(
                    label: '+${CurrencyFormatter.formatPct(rendimiento)}',
                    variant: NBadgeVariant.success,
                    icon: '\u2197',
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
