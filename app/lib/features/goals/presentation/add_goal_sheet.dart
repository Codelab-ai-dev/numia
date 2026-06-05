import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../domain/goal.dart';
import 'goal_types.dart';

class AddGoalSheet extends ConsumerStatefulWidget {
  const AddGoalSheet({super.key, this.onSaved, this.goal});

  final VoidCallback? onSaved;
  final Goal? goal;

  @override
  ConsumerState<AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends ConsumerState<AddGoalSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _monthlyController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedType = goalTypes.first.value;
  DateTime? _targetDate;
  int _priority = 2;
  bool _saving = false;

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final g = widget.goal!;
      _nameController.text = g.name;
      _targetController.text = g.targetAmount.toStringAsFixed(2);
      _monthlyController.text = g.monthlyContribution != null
          ? g.monthlyContribution!.toStringAsFixed(2)
          : '';
      _notesController.text = g.notes ?? '';
      _selectedType = goalTypes.any((t) => t.value == g.type)
          ? g.type
          : goalTypes.last.value;
      _targetDate = g.targetDate;
      _priority = g.priority;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _monthlyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController c) {
    final t = c.text.replaceAll(',', '').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 30),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameController.text.trim();
    final target = _parse(_targetController) ?? 0;
    if (name.isEmpty || target <= 0) return;

    final monthly = _parse(_monthlyController);
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();
    final emoji = goalTypeFor(_selectedType).emoji;

    setState(() => _saving = true);
    try {
      final repo = ref.read(goalRepositoryProvider);
      if (_isEditing) {
        await repo.updateGoal(widget.goal!.id, {
          'type': _selectedType,
          'name': name,
          'target_amount': target,
          'monthly_contribution': monthly,
          'target_date': _targetDate?.toIso8601String().split('T').first,
          'priority': _priority,
          'emoji': emoji,
          'notes': notes,
        });
      } else {
        await repo.addGoal(
          type: _selectedType,
          name: name,
          targetAmount: target,
          monthlyContribution: monthly,
          targetDate: _targetDate,
          priority: _priority,
          emoji: emoji,
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
        title: const Text('Eliminar meta'),
        content: Text('¿Eliminar "${widget.goal!.name}"?'),
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
      await ref.read(goalRepositoryProvider).deleteGoal(widget.goal!.id);
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
        (_parse(_targetController) ?? 0) > 0;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Editar meta' : 'Nueva meta',
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
                decoration: _inputDecoration(ct, 'Ej. Fondo de emergencia'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: NSpacing.sp5),

            // Type selector
            Text('TIPO',
                style: NTypography.overline.copyWith(color: ct.textTertiary)),
            const SizedBox(height: NSpacing.sp3),
            Wrap(
              spacing: NSpacing.sp2,
              runSpacing: NSpacing.sp2,
              children: goalTypes.map((t) {
                final isSelected = _selectedType == t.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t.value),
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
                      '${t.emoji}  ${t.label}',
                      style: NTypography.caption.copyWith(
                        color: isSelected ? ct.accent1 : ct.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: NSpacing.sp5),

            // Target amount
            _LabeledField(
              label: 'MONTO OBJETIVO',
              child: TextField(
                controller: _targetController,
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

            // Monthly contribution
            _LabeledField(
              label: 'APORTE MENSUAL (OPCIONAL)',
              child: TextField(
                controller: _monthlyController,
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

            // Target date
            GestureDetector(
              onTap: _pickDate,
              child: _LabeledField(
                label: 'FECHA OBJETIVO (OPCIONAL)',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 16, color: ct.textSecondary),
                      const SizedBox(width: NSpacing.sp2),
                      Text(
                        _targetDate != null
                            ? '${_targetDate!.day.toString().padLeft(2, '0')}/${_targetDate!.month.toString().padLeft(2, '0')}/${_targetDate!.year}'
                            : 'Seleccionar fecha',
                        style: NTypography.body.copyWith(
                          color: _targetDate != null
                              ? ct.textPrimary
                              : ct.textDisabled,
                        ),
                      ),
                      const Spacer(),
                      if (_targetDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _targetDate = null),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: ct.textTertiary),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: NSpacing.sp5),

            // Priority
            Text('PRIORIDAD',
                style: NTypography.overline.copyWith(color: ct.textTertiary)),
            const SizedBox(height: NSpacing.sp3),
            Row(
              children: [
                _PriorityChip(
                  label: 'Alta',
                  selected: _priority == 3,
                  onTap: () => setState(() => _priority = 3),
                ),
                const SizedBox(width: NSpacing.sp2),
                _PriorityChip(
                  label: 'Media',
                  selected: _priority == 2,
                  onTap: () => setState(() => _priority = 2),
                ),
                const SizedBox(width: NSpacing.sp2),
                _PriorityChip(
                  label: 'Baja',
                  selected: _priority == 1,
                  onTap: () => setState(() => _priority = 1),
                ),
              ],
            ),
            const SizedBox(height: NSpacing.sp5),

            // Notes
            _LabeledField(
              label: 'NOTAS (OPCIONAL)',
              child: TextField(
                controller: _notesController,
                maxLines: 2,
                style: NTypography.body.copyWith(color: ct.textPrimary),
                decoration: _inputDecoration(ct, 'Ej. Para diciembre'),
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

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: NSpacing.sp3),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? ct.accent1.withValues(alpha: 0.15) : ct.surface1,
            borderRadius: BorderRadius.circular(NSpacing.rFull),
            border: Border.all(
              color: selected ? ct.accent1 : ct.borderSubtle,
            ),
          ),
          child: Text(
            label,
            style: NTypography.caption.copyWith(
              color: selected ? ct.accent1 : ct.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
