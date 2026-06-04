import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../domain/budget.dart';
import '../domain/budget_category.dart';

class BudgetSetupScreen extends ConsumerStatefulWidget {
  const BudgetSetupScreen({super.key, this.isEdit = false});

  final bool isEdit;

  @override
  ConsumerState<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends ConsumerState<BudgetSetupScreen> {
  int _currentStep = 0;

  // Step 1 state
  final _amountController = TextEditingController();
  int _cycleStartDay = 1;

  // Step 2 state
  List<BudgetCategory> _categories = [];
  Map<String, TextEditingController> _allocationControllers = {};
  bool _loadingCategories = true;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final repo = ref.read(budgetRepositoryProvider);
    try {
      final cats = await repo.getCategories();
      Budget? budget;
      if (widget.isEdit) {
        budget = await repo.getBudget();
      }

      final controllers = <String, TextEditingController>{};
      for (final cat in cats) {
        String initial = '';
        if (budget != null) {
          final alloc = budget.allocations
              .where((a) => a.categoryId == cat.id)
              .firstOrNull;
          if (alloc != null) {
            initial = alloc.amount.toStringAsFixed(0);
          }
        }
        controllers[cat.id] = TextEditingController(text: initial);
      }

      if (mounted) {
        setState(() {
          _categories = cats;
          _allocationControllers = controllers;
          _loadingCategories = false;
          if (budget != null) {
            _amountController.text = budget.globalAmount.toStringAsFixed(0);
            _cycleStartDay = budget.cycleStartDay;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingCategories = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (final c in _allocationControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _globalAmount =>
      double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  double get _totalAllocated {
    double total = 0;
    for (final c in _allocationControllers.values) {
      total += double.tryParse(c.text.replaceAll(',', '')) ?? 0;
    }
    return total;
  }

  double get _remaining => _globalAmount - _totalAllocated;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(budgetRepositoryProvider);

      await repo.createOrUpdateBudget(
        globalAmount: _globalAmount,
        cycleStartDay: _cycleStartDay,
      );

      final allocations = <Map<String, dynamic>>[];
      for (final cat in _categories) {
        final amount =
            double.tryParse(
                _allocationControllers[cat.id]?.text.replaceAll(',', '') ??
                    '') ??
                0;
        if (amount > 0) {
          allocations.add({
            'category_id': cat.id,
            'amount': amount,
          });
        }
      }

      await repo.setAllocations(allocations);

      ref.invalidate(budgetSummaryProvider);
      ref.invalidate(budgetProvider);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);

    return Scaffold(
      backgroundColor: ct.bg,
      body: NGradientBg(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: NSpacing.pageH, vertical: NSpacing.sp4),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_rounded,
                          color: ct.textPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        widget.isEdit
                            ? 'Editar presupuesto'
                            : 'Nuevo presupuesto',
                        style:
                            NTypography.title.copyWith(color: ct.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              // Step indicators
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
                child: Row(
                  children: [
                    _StepIndicator(
                        stepNumber: 1,
                        label: 'Monto',
                        isActive: _currentStep == 0,
                        isDone: _currentStep > 0,
                        ct: ct),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: _currentStep > 0
                            ? ct.accent1
                            : ct.borderSubtle,
                      ),
                    ),
                    _StepIndicator(
                        stepNumber: 2,
                        label: 'Categorías',
                        isActive: _currentStep == 1,
                        isDone: false,
                        ct: ct),
                  ],
                ),
              ),
              const SizedBox(height: NSpacing.sp6),
              // Step content
              Expanded(
                child: _currentStep == 0
                    ? _buildStep1(context, ct)
                    : _buildStep2(context, ct),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(BuildContext context, NColorTheme ct) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Presupuesto mensual',
            style: NTypography.h2.copyWith(color: ct.textPrimary),
          ),
          const SizedBox(height: NSpacing.sp2),
          Text(
            'Define el total que puedes gastar en el ciclo.',
            style: NTypography.body.copyWith(color: ct.textSecondary),
          ),
          const SizedBox(height: NSpacing.sp6),
          // Amount input
          NGlassCard(
            padding: const EdgeInsets.all(NSpacing.sp4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MONTO TOTAL',
                  style: NTypography.overline.copyWith(color: ct.textTertiary),
                ),
                const SizedBox(height: NSpacing.sp2),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  style: NTypography.numericMd.copyWith(color: ct.textPrimary),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle:
                        NTypography.numericMd.copyWith(color: ct.textSecondary),
                    hintText: '0',
                    hintStyle: NTypography.numericMd
                        .copyWith(color: ct.textDisabled),
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: NSpacing.sp6),
          // Cycle day picker
          NGlassCard(
            padding: const EdgeInsets.all(NSpacing.sp4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DÍA DE INICIO DEL CICLO',
                  style: NTypography.overline.copyWith(color: ct.textTertiary),
                ),
                const SizedBox(height: NSpacing.sp4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CycleButton(
                      icon: Icons.remove,
                      onTap: () {
                        if (_cycleStartDay > 1) {
                          setState(() => _cycleStartDay--);
                        }
                      },
                      ct: ct,
                    ),
                    const SizedBox(width: NSpacing.sp6),
                    Column(
                      children: [
                        Text(
                          '$_cycleStartDay',
                          style: NTypography.numericMd
                              .copyWith(color: ct.textPrimary),
                        ),
                        Text(
                          'cada mes',
                          style: NTypography.caption
                              .copyWith(color: ct.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(width: NSpacing.sp6),
                    _CycleButton(
                      icon: Icons.add,
                      onTap: () {
                        if (_cycleStartDay < 28) {
                          setState(() => _cycleStartDay++);
                        }
                      },
                      ct: ct,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          // Next button
          Padding(
            padding: const EdgeInsets.only(bottom: NSpacing.sp6),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _globalAmount > 0 ? NColors.grad : null,
                  color: _globalAmount > 0 ? null : ct.surface2,
                  borderRadius: BorderRadius.circular(NSpacing.rFull),
                  boxShadow:
                      _globalAmount > 0 ? [NColors.glowIndigo] : [],
                ),
                child: TextButton(
                  onPressed: _globalAmount > 0
                      ? () => setState(() => _currentStep = 1)
                      : null,
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(NSpacing.rFull),
                    ),
                  ),
                  child: Text(
                    'Continuar',
                    style: NTypography.button.copyWith(
                      color: _globalAmount > 0
                          ? Colors.white
                          : ct.textDisabled,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(BuildContext context, NColorTheme ct) {
    final fmt = NumberFormat('#,##0', 'es_MX');

    if (_loadingCategories) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Asigna por categoría',
                style: NTypography.h2.copyWith(color: ct.textPrimary),
              ),
              const SizedBox(height: NSpacing.sp2),
              Text(
                'Distribuye tu presupuesto entre categorías.',
                style: NTypography.body.copyWith(color: ct.textSecondary),
              ),
              const SizedBox(height: NSpacing.sp4),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
            itemCount: _categories.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: NSpacing.sp3),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final controller = _allocationControllers[cat.id]!;
              return NGlassCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: NSpacing.sp4, vertical: NSpacing.sp3),
                child: Row(
                  children: [
                    Text(cat.emoji,
                        style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: NSpacing.sp3),
                    Expanded(
                      child: Text(
                        cat.name,
                        style: NTypography.title
                            .copyWith(color: ct.textPrimary),
                      ),
                    ),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        textAlign: TextAlign.right,
                        style: NTypography.title
                            .copyWith(color: ct.textPrimary),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: NTypography.caption
                              .copyWith(color: ct.textSecondary),
                          hintText: '0',
                          hintStyle: NTypography.title
                              .copyWith(color: ct.textDisabled),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Totals bar
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: NSpacing.pageH, vertical: NSpacing.sp4),
          child: NGlassCard(
            variant: NGlassVariant.featured,
            padding: const EdgeInsets.all(NSpacing.sp4),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Asignado',
                      style:
                          NTypography.caption.copyWith(color: ct.textSecondary),
                    ),
                    Text(
                      '\$${fmt.format(_totalAllocated)} / \$${fmt.format(_globalAmount)}',
                      style:
                          NTypography.title.copyWith(color: ct.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: NSpacing.sp2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Restante',
                      style:
                          NTypography.caption.copyWith(color: ct.textSecondary),
                    ),
                    Text(
                      '\$${fmt.format(_remaining.abs())}${_remaining < 0 ? " (excedido)" : ""}',
                      style: NTypography.caption.copyWith(
                        color: _remaining < 0
                            ? NColors.error
                            : NColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Save button
        Padding(
          padding: const EdgeInsets.fromLTRB(
              NSpacing.pageH, 0, NSpacing.pageH, NSpacing.sp6),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: NColors.grad,
                borderRadius: BorderRadius.circular(NSpacing.rFull),
                boxShadow: const [NColors.glowIndigo],
              ),
              child: TextButton(
                onPressed: _saving ? null : _save,
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
                        'Guardar',
                        style: NTypography.button
                            .copyWith(color: Colors.white),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step Indicator ───────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({
    required this.stepNumber,
    required this.label,
    required this.isActive,
    required this.isDone,
    required this.ct,
  });

  final int stepNumber;
  final String label;
  final bool isActive;
  final bool isDone;
  final NColorTheme ct;

  @override
  Widget build(BuildContext context) {
    final color = (isActive || isDone) ? ct.accent1 : ct.textDisabled;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isActive || isDone)
                ? ct.accent1.withValues(alpha: 0.15)
                : ct.surface2,
            border: Border.all(color: color),
          ),
          child: Center(
            child: isDone
                ? Icon(Icons.check, size: 16, color: color)
                : Text(
                    '$stepNumber',
                    style: NTypography.caption.copyWith(color: color),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: NTypography.overline.copyWith(color: color),
        ),
      ],
    );
  }
}

// ─── Cycle Day Button ─────────────────────────────────────────────────────────

class _CycleButton extends StatelessWidget {
  const _CycleButton({
    required this.icon,
    required this.onTap,
    required this.ct,
  });

  final IconData icon;
  final VoidCallback onTap;
  final NColorTheme ct;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ct.surface2,
          border: Border.all(color: ct.borderDefault),
        ),
        child: Icon(icon, color: ct.textPrimary, size: 20),
      ),
    );
  }
}
