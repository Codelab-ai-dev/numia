import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_gradient_bg.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ct = NColorTheme.of(context);
    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: Center(
          child: Text(
            'Presupuesto',
            style: NTypography.h2.copyWith(color: ct.textPrimary),
          ),
        ),
      ),
    );
  }
}
