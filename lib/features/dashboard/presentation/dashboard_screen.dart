import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/widgets/n_badge.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../../../shared/widgets/n_gradient_text.dart';

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

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: CustomScrollView(
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

              // ── Patrimonio Neto ──
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: NSpacing.pageH),
                  child: _PatrimonioCard(
                    amount: 284750,
                    pctChange: 4.8,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: NSpacing.sp4)),

              // ── Meta activa + Deuda row ──
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: NSpacing.pageH),
                  child: Row(
                    children: [
                      Expanded(
                        child: _GoalMiniCard(
                          name: 'Viaje a Europa',
                          current: 31000,
                          target: 50000,
                        ),
                      ),
                      SizedBox(width: NSpacing.sp3),
                      Expanded(
                        child: _DebtMiniCard(
                          totalDebt: 18400,
                          pctPaid: 34,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: NSpacing.sp4)),

              // ── Insight IA ──
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: NSpacing.pageH),
                  child: _InsightCard(
                    text: 'Pagando \$800 extra al mes, liquidas tu tarjeta 3 meses antes.',
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: NSpacing.sp10)),
            ],
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
  const _PatrimonioCard({required this.amount, required this.pctChange});
  final double amount;
  final double pctChange;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return NGlassCard(
      variant: NGlassVariant.featured,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PATRIMONIO NETO', style: NTypography.overline.copyWith(color: ct.textTertiary)),
          const SizedBox(height: NSpacing.sp3),

          // Amount + badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: NGradientText(
                  CurrencyFormatter.formatMXN(amount),
                  style: NTypography.numericLg,
                ),
              ),
              const SizedBox(width: NSpacing.sp3),
              NBadge(
                label: '+${CurrencyFormatter.formatPct(pctChange)}',
                variant: NBadgeVariant.emerald,
                icon: '\u2197', // ↗
              ),
            ],
          ),

          const SizedBox(height: NSpacing.sp1),
          Text('vs. mes anterior', style: NTypography.caption.copyWith(color: ct.textSecondary)),

          const SizedBox(height: NSpacing.sp5),

          // Mini sparkline
          SizedBox(
            height: 60,
            width: double.infinity,
            child: CustomPaint(painter: _SparklinePainter()),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Mini Sparkline painter
// ─────────────────────────────────────────────
class _SparklinePainter extends CustomPainter {
  static const _points = [
    0.15, 0.12, 0.18, 0.22, 0.20, 0.17, 0.25,
    0.30, 0.28, 0.35, 0.40, 0.38, 0.42, 0.48,
    0.52, 0.50, 0.55, 0.58, 0.62, 0.65, 0.60,
    0.68, 0.72, 0.75, 0.78, 0.82, 0.85, 0.90, 0.92, 0.95,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (_points.isEmpty) return;

    final path = Path();
    final fillPath = Path();
    final dx = size.width / (_points.length - 1);

    for (int i = 0; i < _points.length; i++) {
      final x = dx * i;
      final y = size.height - (_points[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = dx * (i - 1);
        final prevY = size.height - (_points[i - 1] * size.height);
        final cpx = (prevX + x) / 2;
        path.cubicTo(cpx, prevY, cpx, y, x, y);
        fillPath.cubicTo(cpx, prevY, cpx, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x3034D399), Color(0x0034D399)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = NColors.emeraldLight
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    // Glow dot on last point
    final lastX = size.width;
    final lastY = size.height - (_points.last * size.height);
    canvas.drawCircle(
      Offset(lastX, lastY),
      5,
      Paint()..color = NColors.emeraldLight.withValues(alpha: 0.3),
    );
    canvas.drawCircle(
      Offset(lastX, lastY),
      3,
      Paint()..color = NColors.emeraldLight,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────
// Meta activa mini card
// ─────────────────────────────────────────────
class _GoalMiniCard extends StatelessWidget {
  const _GoalMiniCard({
    required this.name,
    required this.current,
    required this.target,
  });
  final String name;
  final double current;
  final double target;

  double get pct => (current / target).clamp(0.0, 1.0);

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
              Text('META ACTIVA', style: NTypography.overline.copyWith(color: ct.textTertiary)),
            ],
          ),
          const SizedBox(height: NSpacing.sp2),
          Text(name, style: NTypography.title.copyWith(color: ct.textPrimary)),
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
              Text(
                '\$${(current / 1000).toInt()}k/\$${(target / 1000).toInt()}k',
                style: NTypography.caption.copyWith(color: ct.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Deuda mini card
// ─────────────────────────────────────────────
class _DebtMiniCard extends StatelessWidget {
  const _DebtMiniCard({required this.totalDebt, required this.pctPaid});
  final double totalDebt;
  final int pctPaid;

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
              Icon(Icons.credit_card_rounded, size: 18, color: ct.accent3),
              const SizedBox(width: NSpacing.sp2),
              Text('DEUDA', style: NTypography.overline.copyWith(color: ct.textTertiary)),
            ],
          ),
          const SizedBox(height: NSpacing.sp2),
          Text(
            CurrencyFormatter.formatMXN(totalDebt),
            style: NTypography.numericMd.copyWith(color: ct.textPrimary),
          ),
          const SizedBox(height: NSpacing.sp3),

          // Progress bar (error/pink color)
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
                    widthFactor: pctPaid / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: NColors.error,
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
                '$pctPaid%',
                style: NTypography.caption.copyWith(
                  color: NColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: NSpacing.sp2),
              Text('pagado', style: NTypography.caption.copyWith(color: ct.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Insight IA card
// ─────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return NGlassCard(
      variant: NGlassVariant.accent,
      accentColor: ct.accent2,
      onTap: () {},
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
                child: Text(text, style: NTypography.body.copyWith(color: ct.textSecondary)),
              ),
              const SizedBox(width: NSpacing.sp2),
              Icon(
                Icons.chevron_right,
                color: ct.textTertiary,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
