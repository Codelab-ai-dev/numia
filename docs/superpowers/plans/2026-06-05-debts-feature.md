# Debts Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a frontend UI so users can register, edit, and delete their debts (deudas), reached by tapping the Deuda card on the dashboard.

**Architecture:** Frontend-only. The Go backend already exposes full CRUD at `/api/v1/debts`. We mirror the existing investments feature: a dedicated `DebtRepository`, a list screen, and a create/edit bottom sheet. The existing `Debt` model is reused. A new `/debts` route is added to the `ShellRoute`, and the dashboard's read-only Deuda mini-card becomes tappable.

**Tech Stack:** Flutter, Riverpod (`FutureProvider`/`Provider`/`ConsumerStatefulWidget`), Dio, go_router, Material 3, project glass widgets (`NGlassCard`, `NBadge`), `CurrencyFormatter`.

**Testing note:** This project has **no automated widget/unit tests** for these screens (the investments feature was verified the same way). Verification is `flutter analyze` (must be clean) plus manual checks on the connected Android device `863d00583048313238510d56e01d4c`. Each task ends with `flutter analyze` and a commit.

---

## File Structure

- Create: `app/lib/features/debts/data/debt_repository.dart` — dedicated repo (getDebts, addDebt, updateDebt, deleteDebt).
- Create: `app/lib/features/debts/presentation/add_debt_sheet.dart` — create/edit/delete bottom sheet.
- Create: `app/lib/features/debts/presentation/debts_screen.dart` — list screen.
- Modify: `app/lib/core/providers.dart` — add `debtRepositoryProvider`, repoint `debtsProvider`, add `/debts` route + import.
- Modify: `app/lib/features/dashboard/data/dashboard_repository.dart` — remove the now-duplicated debt methods (`getDebts`, `addDebt`, `updateDebt`) and the now-unused `debt.dart` import.
- Modify: `app/lib/features/dashboard/presentation/dashboard_screen.dart` — make the Deuda mini-card tappable → `context.push('/debts')`; add go_router import.
- Reuse (no change): `app/lib/features/dashboard/domain/debt.dart` (the `Debt` model).

---

## Task 1: Debt repository + providers

**Files:**
- Create: `app/lib/features/debts/data/debt_repository.dart`
- Modify: `app/lib/core/providers.dart`
- Modify: `app/lib/features/dashboard/data/dashboard_repository.dart`

- [ ] **Step 1: Create the debt repository**

Create `app/lib/features/debts/data/debt_repository.dart` with this exact content. It mirrors `InvestmentRepository` and adds `deleteDebt` (which did not exist before):

```dart
import '../../../core/api_client.dart';
import '../../dashboard/domain/debt.dart';

class DebtRepository {
  DebtRepository(this._client);
  final ApiClient _client;

  Future<List<Debt>> getDebts({bool activeOnly = true}) async {
    final response = await _client.dio.get(
      '/api/v1/debts',
      queryParameters: {'active_only': activeOnly},
    );
    final data = response.data as List;
    return data.map((e) => Debt.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Debt> addDebt({
    required String type,
    required String name,
    required double totalAmount,
    String? institution,
    double? originalAmount,
    double? monthlyPayment,
    double? interestRate,
    String? notes,
  }) async {
    final response = await _client.dio.post('/api/v1/debts', data: {
      'type': type,
      'name': name,
      'total_amount': totalAmount,
      'institution': institution,
      'original_amount': originalAmount,
      'monthly_payment': monthlyPayment,
      'interest_rate': interestRate,
      'notes': notes,
    });
    return Debt.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Debt> updateDebt(String id, Map<String, dynamic> updates) async {
    final response = await _client.dio.put('/api/v1/debts/$id', data: updates);
    return Debt.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteDebt(String id) async {
    await _client.dio.delete('/api/v1/debts/$id');
  }
}
```

- [ ] **Step 2: Remove the duplicated debt methods from DashboardRepository**

In `app/lib/features/dashboard/data/dashboard_repository.dart`, delete the three debt methods (`getDebts`, `addDebt`, `updateDebt`) at lines 45-81 and the now-unused import `import '../domain/debt.dart';` at line 3. After the edit the file keeps `getSummary`, `getAccounts`, `addAccount`, `updateAccountBalance` only. The imports at the top become:

```dart
import '../../../core/api_client.dart';
import '../domain/account.dart';
import '../domain/financial_summary.dart';
```

And the body ends after `updateAccountBalance` (delete everything from `Future<List<Debt>> getDebts(...)` through the final `}` of `updateDebt`, keeping the class's closing brace).

- [ ] **Step 3: Wire the provider and repoint debtsProvider**

In `app/lib/core/providers.dart`:

(a) Add the import next to the other feature imports (after the investments imports, around line 20):

```dart
import '../features/debts/data/debt_repository.dart';
```

(b) Add the repository provider after `investmentRepositoryProvider` (around line 70):

```dart
final debtRepositoryProvider = Provider<DebtRepository>(
  (ref) => DebtRepository(ref.watch(apiClientProvider)),
);
```

(c) Repoint the existing `debtsProvider` (currently at lines 147-150) from `dashboardRepositoryProvider` to `debtRepositoryProvider`:

```dart
final debtsProvider = FutureProvider<List<Debt>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(debtRepositoryProvider).getDebts();
});
```

(`Debt` is already imported in providers.dart via `import '../features/dashboard/domain/debt.dart';`.)

- [ ] **Step 4: Analyze**

Run: `cd app && flutter analyze lib/features/debts lib/core/providers.dart lib/features/dashboard/data/dashboard_repository.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/debts/data/debt_repository.dart app/lib/core/providers.dart app/lib/features/dashboard/data/dashboard_repository.dart
git commit -m "feat: add DebtRepository and debt provider"
```

---

## Task 2: Add/edit/delete debt bottom sheet

**Files:**
- Create: `app/lib/features/debts/presentation/add_debt_sheet.dart`

This mirrors `add_investment_sheet.dart` exactly, adapted to debt fields. It reuses the `_LabeledField` helper, type chips, amount inputs, and delete confirmation.

- [ ] **Step 1: Create the sheet**

Create `app/lib/features/debts/presentation/add_debt_sheet.dart` with this exact content:

```dart
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
          'name': name,
          'total_amount': total,
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
```

- [ ] **Step 2: Analyze**

Run: `cd app && flutter analyze lib/features/debts/presentation/add_debt_sheet.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/debts/presentation/add_debt_sheet.dart
git commit -m "feat: add debt create/edit/delete sheet"
```

---

## Task 3: Debts list screen

**Files:**
- Create: `app/lib/features/debts/presentation/debts_screen.dart`

This mirrors `transactions_screen.dart` (the investments list), adapted to debts. The summary bar shows total debt + total monthly payment. Each row shows the current balance, a paid-percentage bar (when `originalAmount` is present), monthly payment and interest.

- [ ] **Step 1: Create the screen**

Create `app/lib/features/debts/presentation/debts_screen.dart` with this exact content:

```dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../../../shared/utils/currency_formatter.dart';
import '../../../shared/widgets/n_glass_card.dart';
import '../../../shared/widgets/n_gradient_bg.dart';
import '../../dashboard/domain/debt.dart';
import 'add_debt_sheet.dart';

void _openDebtSheet(BuildContext context, WidgetRef ref, {Debt? debt}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddDebtSheet(
      debt: debt,
      onSaved: () {
        ref.invalidate(debtsProvider);
        ref.invalidate(dashboardSummaryProvider);
      },
    ),
  );
}

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  String _selectedFilter = 'Todo';

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final debtsAsync = ref.watch(debtsProvider);

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
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: ct.textPrimary),
                    ),
                    const SizedBox(width: NSpacing.sp2),
                    Text('Deudas',
                        style:
                            NTypography.h1.copyWith(color: ct.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: NSpacing.sp5),

              Expanded(
                child: debtsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorState(
                    onRetry: () => ref.invalidate(debtsProvider),
                  ),
                  data: (debts) {
                    if (debts.isEmpty) {
                      return const _EmptyState();
                    }
                    return _LoadedView(
                      debts: debts,
                      selectedFilter: _selectedFilter,
                      onFilterChanged: (f) =>
                          setState(() => _selectedFilter = f),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDebtSheet(context, ref),
        backgroundColor: ct.accent1,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Loaded view — filters, list and summary
// ─────────────────────────────────────────────
class _LoadedView extends ConsumerWidget {
  const _LoadedView({
    required this.debts,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final List<Debt> debts;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final types = <String>['Todo'];
    for (final d in debts) {
      if (!types.contains(d.type)) types.add(d.type);
    }
    final effectiveFilter =
        types.contains(selectedFilter) ? selectedFilter : 'Todo';
    final visible = effectiveFilter == 'Todo'
        ? debts
        : debts.where((d) => d.type == effectiveFilter).toList();

    final totalDebt = debts.fold<double>(0, (sum, d) => sum + d.totalAmount);
    final totalPayment =
        debts.fold<double>(0, (sum, d) => sum + (d.monthlyPayment ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Filter chips ──
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
            itemCount: types.length,
            separatorBuilder: (_, __) => const SizedBox(width: NSpacing.sp2),
            itemBuilder: (context, i) => _FilterChip(
              label: types[i],
              selected: effectiveFilter == types[i],
              onTap: () => onFilterChanged(types[i]),
            ),
          ),
        ),
        const SizedBox(height: NSpacing.sp5),

        // ── Debt list ──
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(debtsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
              itemCount: visible.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: NSpacing.sp3),
              itemBuilder: (context, i) => _DebtRow(
                debt: visible[i],
                onTap: () => _openDebtSheet(context, ref, debt: visible[i]),
              ),
            ),
          ),
        ),

        // ── Bottom summary bar ──
        _SummaryBar(totalDebt: totalDebt, totalPayment: totalPayment),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Empty + error states
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.credit_card_off_rounded,
                size: 48, color: ct.textTertiary),
            const SizedBox(height: NSpacing.sp4),
            Text(
              'Aún no tienes deudas',
              style: NTypography.title.copyWith(color: ct.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NSpacing.sp2),
            Text(
              'Agrega tu primera deuda con el botón +',
              style: NTypography.body.copyWith(color: ct.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NSpacing.pageH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 48, color: ct.textTertiary),
            const SizedBox(height: NSpacing.sp4),
            Text(
              'No pudimos cargar tus deudas',
              style: NTypography.title.copyWith(color: ct.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NSpacing.sp4),
            TextButton(
              onPressed: onRetry,
              child: Text('Reintentar',
                  style: NTypography.button.copyWith(color: ct.accent1)),
            ),
          ],
        ),
      ),
    );
  }
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
// Debt row — glass card
// ─────────────────────────────────────────────
class _DebtRow extends StatelessWidget {
  const _DebtRow({required this.debt, required this.onTap});
  final Debt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ct = NColorTheme.of(context);
    final paidPct = debt.paidPercentage;
    final showProgress = debt.originalAmount != null && debt.originalAmount! > 0;
    final subtitle = debt.institution?.isNotEmpty == true
        ? '${debt.type} · ${debt.institution}'
        : debt.type;

    return NGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: NSpacing.sp5,
        vertical: NSpacing.sp4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Name + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(debt.name,
                        style: NTypography.title
                            .copyWith(color: ct.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NTypography.caption
                          .copyWith(color: ct.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NSpacing.sp3),

              // Current balance
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatMXN(debt.totalAmount),
                    style:
                        NTypography.title.copyWith(color: ct.textPrimary),
                  ),
                  if (debt.interestRate != null && debt.interestRate! > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${CurrencyFormatter.formatPct(debt.interestRate!)} interés',
                      style: NTypography.caption
                          .copyWith(color: ct.textSecondary),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Paid progress bar
          if (showProgress) ...[
            const SizedBox(height: NSpacing.sp3),
            ClipRRect(
              borderRadius: BorderRadius.circular(NSpacing.rFull),
              child: LinearProgressIndicator(
                value: paidPct,
                minHeight: 6,
                backgroundColor: ct.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(ct.accent1),
              ),
            ),
            const SizedBox(height: NSpacing.sp2),
            Text(
              '${CurrencyFormatter.formatPct(paidPct * 100)} pagado',
              style: NTypography.caption.copyWith(color: ct.textTertiary),
            ),
          ],

          // Monthly payment
          if (debt.monthlyPayment != null && debt.monthlyPayment! > 0) ...[
            const SizedBox(height: NSpacing.sp2),
            Text(
              'Pago mensual ${CurrencyFormatter.formatMXN(debt.monthlyPayment!)}',
              style: NTypography.caption.copyWith(
                color: NColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom summary bar — glass
// ─────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.totalDebt, required this.totalPayment});
  final double totalDebt;
  final double totalPayment;

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DEUDA TOTAL',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp1),
                  Text(
                    CurrencyFormatter.formatMXN(totalDebt),
                    style: NTypography.numericLg
                        .copyWith(color: ct.textPrimary),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('PAGO MENSUAL',
                      style: NTypography.overline
                          .copyWith(color: ct.textTertiary)),
                  const SizedBox(height: NSpacing.sp1),
                  Text(
                    CurrencyFormatter.formatMXN(totalPayment),
                    style: NTypography.numericLg
                        .copyWith(color: NColors.error),
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
```

- [ ] **Step 2: Analyze**

Run: `cd app && flutter analyze lib/features/debts`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/debts/presentation/debts_screen.dart
git commit -m "feat: add debts list screen"
```

---

## Task 4: Wire the route and make the dashboard mini-card tappable

**Files:**
- Modify: `app/lib/core/providers.dart`
- Modify: `app/lib/features/dashboard/presentation/dashboard_screen.dart`

- [ ] **Step 1: Register the /debts route**

In `app/lib/core/providers.dart`, add the import near the other presentation imports (after the budget/coach/dashboard imports, around line 26-32):

```dart
import '../features/debts/presentation/debts_screen.dart';
```

Then add the route inside the `ShellRoute`'s `routes:` list, right after the `/transactions` route (currently line 127):

```dart
          GoRoute(path: '/debts', builder: (_, __) => const DebtsScreen()),
```

- [ ] **Step 2: Make the Deuda mini-card tappable**

In `app/lib/features/dashboard/presentation/dashboard_screen.dart`:

(a) Add the go_router import after the flutter_riverpod import (line 2):

```dart
import 'package:go_router/go_router.dart';
```

(b) In `_DebtMiniCard.build` (around line 332), add an `onTap` to the `NGlassCard` so tapping navigates to `/debts`. Change:

```dart
    return NGlassCard(
      padding: const EdgeInsets.all(NSpacing.sp5),
      child: Column(
```

to:

```dart
    return NGlassCard(
      onTap: () => context.push('/debts'),
      padding: const EdgeInsets.all(NSpacing.sp5),
      child: Column(
```

- [ ] **Step 3: Analyze**

Run: `cd app && flutter analyze lib/core/providers.dart lib/features/dashboard/presentation/dashboard_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add app/lib/core/providers.dart app/lib/features/dashboard/presentation/dashboard_screen.dart
git commit -m "feat: wire /debts route and tappable dashboard debt card"
```

---

## Task 5: Full analyze + manual verification

**Files:** none (verification only)

- [ ] **Step 1: Full analyze**

Run: `cd app && flutter analyze`
Expected: No new issues in `lib/features/debts`, `lib/core/providers.dart`, or `lib/features/dashboard`. (Pre-existing infos in `budget_screen.dart` may remain — do not touch them.)

- [ ] **Step 2: Run on device and verify the flow**

Run: `cd app && flutter run -d 863d00583048313238510d56e01d4c`

Manually verify on the device:
- Dashboard loads; tap the **Deuda** mini-card → the Deudas screen opens.
- Empty state shows "Aún no tienes deudas".
- Tap **+** → fill Nombre + Saldo actual, pick a Tipo, tap **Guardar** → the debt appears in the list and the dashboard Deuda mini-card total updates after going back.
- Tap a debt row → edit it (change Saldo actual / Pago mensual) → **Actualizar** → changes persist.
- In edit mode tap the trash icon → confirm → the debt is removed from the list and the dashboard total updates.
- The bottom summary bar shows Deuda total and Pago mensual.

- [ ] **Step 3: Confirm no console layout exceptions**

While the app runs, confirm the console shows no `BoxConstraints`/`RenderBox`/`hasSize` exceptions on the Deudas screen.

---

## Self-Review Notes

- **Spec coverage:** repository with deleteDebt (Task 1) ✓; list screen with summary/filters/cards/empty/error (Task 3) ✓; create/edit/delete sheet with all chosen fields (Task 2) ✓; `/debts` route + tappable mini-card (Task 4) ✓; invalidates both `debtsProvider` and `dashboardSummaryProvider` on save/delete (Task 3 `_openDebtSheet`) ✓; manual verification (Task 5) ✓.
- **Type consistency:** `debtRepositoryProvider`, `debtsProvider`, `DebtRepository`, `AddDebtSheet(debt:, onSaved:)`, `DebtsScreen`, `Debt.paidPercentage` are used consistently across tasks.
- **Edit request fields:** update sends `name`, `total_amount`, `monthly_payment`, `interest_rate`, `notes` — exactly the fields the backend `UpdateRequest` accepts (type/institution/original_amount are not updatable per backend, matching the investments edit pattern).
