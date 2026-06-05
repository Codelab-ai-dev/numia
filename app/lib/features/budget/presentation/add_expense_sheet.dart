import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../domain/budget_category.dart';
import '../domain/expense.dart';

class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key, this.onSaved, this.expense});

  final VoidCallback? onSaved;
  final Expense? expense;

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<AddExpenseSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subcategoryController = TextEditingController();

  List<BudgetCategory> _categories = [];
  String? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.expense!;
      _amountController.text = e.amount.toStringAsFixed(2);
      _descriptionController.text = e.description ?? '';
      _subcategoryController.text = e.subcategory ?? '';
      _selectedCategoryId = e.categoryId;
      _selectedDate = e.expenseDate;
    }
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ref.read(budgetRepositoryProvider).getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _subcategoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (_selectedCategoryId == null || amount <= 0) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(budgetRepositoryProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final desc = _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text;
      final subcat = _subcategoryController.text.isEmpty
          ? null
          : _subcategoryController.text;

      if (_isEditing) {
        await repo.updateExpense(
          id: widget.expense!.id,
          categoryId: _selectedCategoryId!,
          amount: amount,
          expenseDate: dateStr,
          description: desc,
          subcategory: subcat,
        );
      } else {
        await repo.createExpense(
          categoryId: _selectedCategoryId!,
          amount: amount,
          expenseDate: dateStr,
          description: desc,
          subcategory: subcat,
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

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final dateFmt = DateFormat('d MMM yyyy', 'es');
    final canSave = _selectedCategoryId != null &&
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
            // Title
            Text(
              _isEditing ? 'Editar gasto' : 'Nuevo gasto',
              style: NTypography.h2.copyWith(color: ct.textPrimary),
            ),
            const SizedBox(height: NSpacing.sp6),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Category selector
              Text(
                'CATEGORIA',
                style: NTypography.overline.copyWith(color: ct.textTertiary),
              ),
              const SizedBox(height: NSpacing.sp3),
              Wrap(
                spacing: NSpacing.sp2,
                runSpacing: NSpacing.sp2,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedCategoryId = cat.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: NSpacing.sp3, vertical: NSpacing.sp2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ct.accent1.withValues(alpha: 0.15)
                            : ct.surface1,
                        borderRadius:
                            BorderRadius.circular(NSpacing.rFull),
                        border: Border.all(
                          color:
                              isSelected ? ct.accent1 : ct.borderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.emoji,
                              style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: NSpacing.sp2),
                          Text(
                            cat.name,
                            style: NTypography.caption.copyWith(
                              color: isSelected
                                  ? ct.accent1
                                  : ct.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: NSpacing.sp5),

              // Amount input
              NGlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: NSpacing.sp4, vertical: NSpacing.sp3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MONTO',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary),
                    ),
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      autofocus: false,
                      style: NTypography.numericMd
                          .copyWith(color: ct.textPrimary),
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
              const SizedBox(height: NSpacing.sp3),

              // Date picker
              NGlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: NSpacing.sp4, vertical: NSpacing.sp3),
                onTap: _pickDate,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: ct.textSecondary),
                    const SizedBox(width: NSpacing.sp3),
                    Text(
                      dateFmt.format(_selectedDate),
                      style:
                          NTypography.title.copyWith(color: ct.textPrimary),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        color: ct.textTertiary),
                  ],
                ),
              ),
              const SizedBox(height: NSpacing.sp3),

              // Description
              NGlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: NSpacing.sp4, vertical: NSpacing.sp3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DESCRIPCION (OPCIONAL)',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary),
                    ),
                    TextField(
                      controller: _descriptionController,
                      style:
                          NTypography.body.copyWith(color: ct.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ej. Cena con amigos',
                        hintStyle: NTypography.body
                            .copyWith(color: ct.textDisabled),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NSpacing.sp3),

              // Subcategory
              NGlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: NSpacing.sp4, vertical: NSpacing.sp3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUBCATEGORIA (OPCIONAL)',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary),
                    ),
                    TextField(
                      controller: _subcategoryController,
                      style:
                          NTypography.body.copyWith(color: ct.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Ej. Restaurante',
                        hintStyle: NTypography.body
                            .copyWith(color: ct.textDisabled),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
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
                        borderRadius:
                            BorderRadius.circular(NSpacing.rFull),
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
                              color: canSave
                                  ? Colors.white
                                  : ct.textDisabled,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
