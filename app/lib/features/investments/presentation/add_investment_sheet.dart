import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../domain/investment.dart';

const _investmentTypes = [
  'CETES',
  'ETF',
  'Fondo',
  'Acciones',
  'Cripto',
  'Ahorro',
  'Otro',
];

class AddInvestmentSheet extends ConsumerStatefulWidget {
  const AddInvestmentSheet({super.key, this.onSaved, this.investment});

  final VoidCallback? onSaved;
  final Investment? investment;

  @override
  ConsumerState<AddInvestmentSheet> createState() =>
      _AddInvestmentSheetState();
}

class _AddInvestmentSheetState extends ConsumerState<AddInvestmentSheet> {
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  final _amountController = TextEditingController();
  final _currentValueController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = _investmentTypes.first;
  bool _saving = false;

  bool get _isEditing => widget.investment != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final inv = widget.investment!;
      _nameController.text = inv.name;
      _institutionController.text = inv.institution ?? '';
      _amountController.text = inv.amountInvested.toStringAsFixed(2);
      _currentValueController.text = inv.currentValue.toStringAsFixed(2);
      _notesController.text = inv.notes ?? '';
      _selectedType = _investmentTypes.contains(inv.type)
          ? inv.type
          : _investmentTypes.last;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _amountController.dispose();
    _currentValueController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (name.isEmpty || amount <= 0) return;

    final currentValue =
        double.tryParse(_currentValueController.text.replaceAll(',', ''));
    final institution = _institutionController.text.trim().isEmpty
        ? null
        : _institutionController.text.trim();
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    setState(() => _saving = true);
    try {
      final repo = ref.read(investmentRepositoryProvider);
      if (_isEditing) {
        await repo.updateInvestment(widget.investment!.id, {
          'name': name,
          'institution': institution,
          'type': _selectedType,
          'amount_invested': amount,
          'current_value': currentValue ?? amount,
          'notes': notes,
        });
      } else {
        await repo.addInvestment(
          name: name,
          institution: institution,
          type: _selectedType,
          amountInvested: amount,
          currentValue: currentValue,
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
        title: const Text('Eliminar inversión'),
        content: Text('¿Eliminar "${widget.investment!.name}"?'),
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
      await ref
          .read(investmentRepositoryProvider)
          .deleteInvestment(widget.investment!.id);
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
        (double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0) > 0;

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
                    _isEditing ? 'Editar inversión' : 'Nueva inversión',
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
                decoration: _inputDecoration(ct, 'Ej. CETES 28 días'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: NSpacing.sp3),

            // Institution / broker
            _LabeledField(
              label: 'INSTITUCIÓN / BROKER (OPCIONAL)',
              child: TextField(
                controller: _institutionController,
                style: NTypography.body.copyWith(color: ct.textPrimary),
                decoration: _inputDecoration(ct, 'Ej. CETES Directo, GBM+'),
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
              children: _investmentTypes.map((type) {
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
                        color:
                            isSelected ? ct.accent1 : ct.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: NSpacing.sp5),

            // Amount invested
            _LabeledField(
              label: 'MONTO INVERTIDO',
              child: TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                style: NTypography.numericMd.copyWith(color: ct.textPrimary),
                decoration: _amountDecoration(ct),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: NSpacing.sp3),

            // Current value
            _LabeledField(
              label: 'VALOR ACTUAL (OPCIONAL)',
              child: TextField(
                controller: _currentValueController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}')),
                ],
                style: NTypography.numericMd.copyWith(color: ct.textPrimary),
                decoration: _amountDecoration(ct),
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
                decoration: _inputDecoration(ct, 'Ej. Vence en marzo'),
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
                            color:
                                canSave ? Colors.white : ct.textDisabled,
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
