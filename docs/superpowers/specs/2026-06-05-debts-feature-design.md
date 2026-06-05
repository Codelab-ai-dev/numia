# Debts Feature Design

**Date:** 2026-06-05
**Status:** Approved

## Goal

Add a frontend UI for users to register and manage their debts (deudas). The Go backend already exposes full CRUD; this feature is frontend-only and mirrors the existing investments feature.

## Context

- Backend already has full CRUD at `/api/v1/debts`:
  - `GET /api/v1/debts?active_only={bool}` — list
  - `POST /api/v1/debts` — create
  - `PUT /api/v1/debts/:id` — update
  - `DELETE /api/v1/debts/:id` — delete
- The `Debt` domain model already exists at `app/lib/features/dashboard/domain/debt.dart` and is reused as-is.
- Debt read/add/update methods currently live in `DashboardRepository`; the dashboard only shows a read-only summary mini-card (`_DebtMiniCard`). There is no UI to create/manage debts and no `deleteDebt` method on the frontend.

## Architecture

Frontend-only, mirroring the investments feature layout. New folder `app/lib/features/debts/`:

```
app/lib/features/debts/
├── data/
│   └── debt_repository.dart        # dedicated repo: getDebts, addDebt, updateDebt, deleteDebt
└── presentation/
    ├── debts_screen.dart           # list screen
    └── add_debt_sheet.dart         # create/edit/delete bottom sheet
```

- The `Debt` model stays in `dashboard/domain/debt.dart` (reused, not moved).
- New providers in `core/providers.dart`: `debtRepositoryProvider`. The existing `debtsProvider` is repointed to `debtRepositoryProvider`.
- New route `/debts` registered inside the existing `ShellRoute`.
- `_DebtMiniCard` on the dashboard becomes tappable → `context.push('/debts')`.

### debt_repository.dart

Mirror `InvestmentRepository`. Methods:
- `getDebts({bool activeOnly = true})` → `GET /api/v1/debts?active_only=...` → `List<Debt>`
- `addDebt({...})` → `POST /api/v1/debts` → returns created `Debt`
- `updateDebt(String id, Map<String, dynamic> updates)` → `PUT /api/v1/debts/:id`
- `deleteDebt(String id)` → `DELETE /api/v1/debts/:id` (new — does not exist today)

Create request body fields: `type`, `name`, `institution?`, `total_amount`, `original_amount?`, `monthly_payment?`, `interest_rate?`, `notes?`.

## Components

### debts_screen.dart (list)

Mirror `transactions_screen.dart` (the investments screen):
- `ConsumerStatefulWidget`, title "Deudas".
- Consumes `debtsProvider` with `.when(loading → spinner, error → error state with retry, data → loaded/empty)`.
- **Summary bar**: total debt (sum of `totalAmount`), total monthly payment (sum of `monthlyPayment`), count of active debts.
- **Filter chips**: `['Todo']` + distinct `type` values present in the data.
- **Debt cards**: each shows name, institution (if any), current balance (`totalAmount`), a paid-percentage bar when `originalAmount` is present (uses `Debt.paidPercentage`), monthly payment and interest rate when present. Tap a card → open edit sheet.
- **FAB +** to add a new debt.
- `RefreshIndicator` that invalidates `debtsProvider`.
- Empty state and error state widgets.

### add_debt_sheet.dart (create/edit/delete)

Mirror `add_investment_sheet.dart`:
- `ConsumerStatefulWidget`, supports create and edit (`Debt? debt`).
- Fields:
  - Nombre — required text.
  - Tipo — selectable chips: `Tarjeta de crédito`, `Préstamo personal`, `Hipoteca`, `Auto`, `Educativo`, `Otro`. The chip label is sent as the `type` string.
  - Saldo actual (`total_amount`) — required, numeric with decimal formatter.
  - Monto original (`original_amount`) — optional, numeric.
  - Pago mensual (`monthly_payment`) — optional, numeric.
  - Tasa de interés % (`interest_rate`) — optional, numeric.
  - Institución (`institution`) — optional text.
  - Notas (`notes`) — optional multiline text.
- Save button "Guardar"/"Actualizar" with gradient, disabled until name and saldo actual > 0.
- In edit mode: a delete icon button that shows a confirmation dialog, then calls `deleteDebt`.
- `onSaved` callback.

## Data Flow

1. User taps the Deuda mini-card on the dashboard → `context.push('/debts')`.
2. `debts_screen` reads `debtsProvider` → `debtRepositoryProvider.getDebts()`.
3. User taps FAB → `add_debt_sheet` in create mode; or taps a card → edit mode.
4. On save/delete success: `ref.invalidate(debtsProvider)` and `ref.invalidate(dashboardSummaryProvider)` so both the list and the dashboard mini-card refresh. Pop the sheet.

## Error Handling

- Repository surfaces Dio errors; the screen's `.when` error branch shows a retry.
- Save/delete failures in the sheet show a `SnackBar` ("Error al guardar: ..." / "Error al eliminar: ...") and re-enable the form, matching the investments sheet.

## Testing

Manual verification on the connected Android device (no automated widget tests exist in this project; follow the existing manual-verification approach used for investments):
- `flutter analyze` clean.
- Launch app, open dashboard, tap Deuda mini-card → debts screen loads.
- Create a debt → appears in list and updates the dashboard mini-card total.
- Edit a debt → changes persist.
- Delete a debt → removed from list and dashboard total updates.
- Empty and error states render.

## Out of Scope (YAGNI)

- No new backend changes (backend CRUD already complete).
- No automated tests (project has none for these screens).
- No debt payoff projections / amortization schedules.
- No dedicated nav-bar tab (reached via dashboard mini-card per user decision).
