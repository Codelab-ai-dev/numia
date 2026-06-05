import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../dashboard/domain/debt.dart';

const _debtTypes = [
  'Tarjeta de crédito',
  'Préstamo personal',
  'Hipoteca',
  'Auto',
  'Educativo',
  'Otro',
];

class AddDebtSheet extends ConsumerStatefulWidget {
  const AddDebtSheet({super.key, this.onSaved, this.debt});

  final VoidCallback? onSaved;
  final Debt? debt;

  @override
  ConsumerState<AddDebtSheet> createState() => _AddDebtSheetState();
}

class _AddDebtSheetState extends ConsumerState<AddDebtSheet> {
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _totalController = TextEditingController();
  final _originalController = TextEditingController();
  final _paymentController = TextEditingController();
  final _interestController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = _debtTypes.first;
  bool _saving = false;

  bool get _isEditing => widget.debt != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final d = widget.debt!;
      _nameController.text = d.name;
      _institutionController.text = d.institution ?? '';
      _totalController.text = d.totalAmount.toStringAsFixed(2);
      _originalController.text =
          d.originalAmount != null ? d.originalAmount!.toStringAsFixed(2) : '';
      _paymentController.text =
          d.monthlyPayment != null ? d.monthlyPayment!.toStringAsFixed(2) : '';
      _interestController.text =
          d.interestRate != null ? d.interestRate!.toStringAsFixed(2) : '';
      _notesController.text = d.notes ?? '';
      _selectedType =
          _debtTypes.contains(d.type) ? d.type : _debtTypes.last;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _totalController.dispose();
    _originalController.dispose();
    _paymentController.dispose();
    _interestController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) {
    final t = c.text.replaceAll(',', '').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final total = _parse(_totalController) ?? 0;
    if (name.isEmpty || total <= 0) return;

    final original = _parse(_originalController);
    final payment = _parse(_paymentController);
    final interest = _parse(_interestController);
    final institution = _institutionController.text.trim().isEmpty
        ? null
        : _institutionController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    setState(() => _saving = true);
    try {
      final repo = ref.read(debtRepositoryProvider);
      if (_isEditing) {
        await repo.updateDebt(widget.debt!.id, {
          'type': _selectedType,
          'name': name,
          'institution': institution,
          'total_amount': total,
          'original_amount': original,
          'monthly_payment': payment,
          'interest_rate': interest,
          'notes': notes,
        });
      } else {
        await repo.addDebt(
          type: _selectedType,
          name: name,
          totalAmount: total,
          institution: institution,
          originalAmount: original,
          monthlyPayment: payment,
          interestRate: interest,
          notes: notes,
        );
      }
      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (_saving || !_isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar deuda'),
        content: Text('¿Eliminar "${widget.debt!.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(debtRepositoryProvider).deleteDebt(widget.debt!.id);
      widget.onSaved?.call();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final canSave = _nameController.text.trim().isNotEmpty &&
        (_parse(_totalController) ?? 0) > 0;

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
            // Handle
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
            // Title row
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Editar deuda' : 'Nueva deuda',
                    style: NTypography.h2.copyWith(color: ct.textPrimary),
                  ),
                ),
                if (_isEditing)
                  IconButton(
                    onPressed: _saving ? null : _delete,
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: NColors.error),
                  ),
              ],
            ),
            const SizedBox(height: NSpacing.sp5),

            // Name
            _LabeledField(
              label: 'NOMBRE',
              child: TextField(
                controller: _nameController,
                style: NTypography.body.copyWith(color: ct.textPrimary),
                decoration: _inputDecoration(ct, 'Ej. Tarjeta BBVA'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: NSpacing.sp3),

            // Institution
            _LabeledField(
              label: 'INSTITUCIÓN (OPCIONAL)',
              child: TextField(
                controller: _institutionController,
                style: NTypography.body.copyWith(color: ct.textPrimary),
                decoration: _inputDecoration(ct, 'Ej. BBVA, Nu, HSBC'),
              ),
            ),
            const SizedBox(height: NSpacing.sp5),

            // Type selector
            Text(
              'TIPO',
              style: NTypography.overline.copyWith(color: ct.textTertiary),
            ),
            const SizedBox(height: NSpacing.sp3),
            Wrap(
              spacing: NSpacing.sp2,
              runSpacing: NSpacing.sp2,
              children: _debtTypes.map((type) {
                final isSelected = _selectedType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: NSpacing.sp3, vertical: NSpacing.sp2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? ct.accent1.withValues(alpha: 0.15)
                          : ct.surface1,
                      borderRadius: BorderRadius.circular(NSpacing.rFull),
                      border: Border.all(
                        color: isSelected ? ct.accent1 : ct.borderSubtle,
                      ),
                    ),
                    child: Text(
                      type,
                      style: NTypography.caption.copyWith(
                        color: isSelected ? ct.accent1 : ct.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: NSpacing.sp5),

            // Current balance (total_amount)
            _LabeledField(
              label: 'SALDO ACTUAL',
              child: TextField(
                controller: _totalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                style: NTypography.numericMd.copyWith(color: ct.textPrimary),
                decoration: _amountDecoration(ct),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: NSpacing.sp3),

            // Original amount
            _LabeledField(
              label: 'MONTO ORIGINAL (OPCIONAL)',
              child: TextField(
                controller: _originalController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                style: NTypography.numericMd.copyWith(color: ct.textPrimary),
                decoration: _amountDecoration(ct),
              ),
            ),
            const SizedBox(height: NSpacing.sp3),

            // Monthly payment
            _LabeledField(
              label: 'PAGO MENSUAL (OPCIONAL)',
              child: TextField(
                controller: _paymentController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                style: NTypography.numericMd.copyWith(color: ct.textPrimary),
                decoration: _amountDecoration(ct),
              ),
            ),
            const SizedBox(height: NSpacing.sp3),

            // Interest rate
            _LabeledField(
              label: 'TASA DE INTERÉS % (OPCIONAL)',
              child: TextField(
                controller: _interestController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                style: NTypography.numericMd.copyWith(color: ct.textPrimary),
                decoration: _inputDecoration(ct, '0'),
              ),
            ),
            const SizedBox(height: NSpacing.sp3),

            // Notes
            _LabeledField(
              label: 'NOTAS (OPCIONAL)',
              child: TextField(
                controller: _notesController,
                maxLines: 2,
                style: NTypography.body.copyWith(color: ct.textPrimary),
                decoration: _inputDecoration(ct, 'Ej. Corte el día 15'),
              ),
            ),
            const SizedBox(height: NSpacing.sp6),

            // Save button
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
                          _isEditing ? 'Actualizar' : 'Guardar',
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

  InputDecoration _inputDecoration(NColorTheme ct, String hint) =>
      InputDecoration(
        hintText: hint,
        hintStyle: NTypography.body.copyWith(color: ct.textDisabled),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      );

  InputDecoration _amountDecoration(NColorTheme ct) => InputDecoration(
        prefixText: '\$ ',
        prefixStyle: NTypography.numericMd.copyWith(color: ct.textSecondary),
        hintText: '0',
        hintStyle: NTypography.numericMd.copyWith(color: ct.textDisabled),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      );
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return NGlassCard(
      padding: const EdgeInsets.symmetric(
          horizontal: NSpacing.sp4, vertical: NSpacing.sp3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: NTypography.overline.copyWith(color: ct.textTertiary)),
          child,
        ],
      ),
    );
  }
}
