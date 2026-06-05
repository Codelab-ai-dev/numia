import 'package:flutter/material.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_gradient_bg.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: NSpacing.sp5),
                Text('Metas', style: NTypography.h1.copyWith(color: ct.textPrimary)),
                const SizedBox(height: NSpacing.sp8),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 48,
                          color: ct.accent3,
                        ),
                        const SizedBox(height: NSpacing.sp4),
                        Text(
                          'Próximamente',
                          style: NTypography.title.copyWith(color: ct.textSecondary),
                        ),
                        const SizedBox(height: NSpacing.sp2),
                        Text(
                          'Aquí podrás crear y dar seguimiento\na tus metas financieras',
                          style: NTypography.body.copyWith(color: ct.textTertiary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
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
