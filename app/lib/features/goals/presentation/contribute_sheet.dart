import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../domain/goal.dart';

class ContributeSheet extends ConsumerStatefulWidget {
  const ContributeSheet({super.key, required this.goal, this.onSaved});

  final Goal goal;
  final VoidCallback? onSaved;

  @override
  ConsumerState<ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends ConsumerState<ContributeSheet> {
  final _amountController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? _parse() {
    final t = _amountController.text.replaceAll(',', '').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = _parse() ?? 0;
    if (amount <= 0) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(goalRepositoryProvider);
      await repo.addContribution(widget.goal.id, amount);
      final newTotal = widget.goal.currentAmount + amount;
      if (newTotal >= widget.goal.targetAmount &&
          widget.goal.status == 'active') {
        await repo.updateGoal(widget.goal.id, {'status': 'completed'});
      }
      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abonar: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final g = widget.goal;
    final canSave = (_parse() ?? 0) > 0;

    return Container(
      decoration: BoxDecoration(
        color: ct.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NSpacing.rXl),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        NSpacing.pageH,
        NSpacing.sp4,
        NSpacing.pageH,
        MediaQuery.of(context).viewInsets.bottom + NSpacing.sp6,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ct.borderDefault,
                  borderRadius: BorderRadius.circular(NSpacing.rFull),
                ),
              ),
            ),
            const SizedBox(height: NSpacing.sp4),
            Text('Abonar a meta',
                style: NTypography.h2.copyWith(color: ct.textPrimary)),
            const SizedBox(height: NSpacing.sp2),
            Text(g.name,
                style: NTypography.body.copyWith(color: ct.textSecondary)),
            const SizedBox(height: NSpacing.sp1),
            Text(
              '${CurrencyFormatter.formatMXN(g.currentAmount)} / ${CurrencyFormatter.formatMXN(g.targetAmount)}',
              style: NTypography.caption.copyWith(color: ct.textTertiary),
            ),
            const SizedBox(height: NSpacing.sp5),
            NGlassCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: NSpacing.sp4, vertical: NSpacing.sp3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MONTO A ABONAR',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary)),
                  TextField(
                    controller: _amountController,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    style:
                        NTypography.numericMd.copyWith(color: ct.textPrimary),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: NTypography.numericMd
                          .copyWith(color: ct.textSecondary),
                      hintText: '0',
                      hintStyle: NTypography.numericMd
                          .copyWith(color: ct.textDisabled),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NSpacing.sp6),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: canSave ? NColors.grad : null,
                  color: canSave ? null : ct.surface2,
                  borderRadius: BorderRadius.circular(NSpacing.rFull),
                  boxShadow: canSave ? [NColors.glowIndigo] : [],
                ),
                child: TextButton(
                  onPressed: canSave && !_saving ? _save : null,
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(NSpacing.rFull),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Abonar',
                          style: NTypography.button.copyWith(
                            color: canSave ? Colors.white : ct.textDisabled,
                          ),
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
