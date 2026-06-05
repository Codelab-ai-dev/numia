# Metas (Financial Goals) — Design Spec

**Date:** 2026-06-05
**Status:** Approved

## Overview

Build the **frontend** for the "Metas" (financial goals) feature. The Go backend is
already complete and deployed: a `goals` table, a service with CRUD + a contribution
endpoint, and 5 routes under `/goals`. The Flutter app already has the `Goal` domain
model, `goal_repository.dart` (with `addContribution`), `goalRepositoryProvider`,
`goalsProvider`, the bottom-nav "Metas" tab, and the `/goals` route — but
`GoalsScreen` is only a placeholder ("Próximamente").

This feature mirrors the just-built **debts** feature, with two additions unique to
goals: a **contribute** flow (add money toward a goal via `POST /goals/:id/contribute`)
and **auto-completion** (when a contribution pushes progress to ≥100%, the frontend
sends `PUT /goals/:id` with `status='completed'`).

## Backend (already implemented — reference only)

`goals` table columns: `id`, `user_id`, `type` (TEXT NOT NULL), `name` (TEXT NOT NULL),
`target_amount` (NUMERIC NOT NULL), `current_amount` (NUMERIC NOT NULL DEFAULT 0),
`monthly_contribution` (NUMERIC nullable), `target_date` (DATE nullable),
`priority` (SMALLINT NOT NULL DEFAULT 1), `status` (TEXT NOT NULL DEFAULT 'active'),
`emoji` (TEXT nullable), `notes` (TEXT nullable), `created_at`, `updated_at`.

Endpoints (auth-protected):
- `GET /goals?status=<optional>` — list, optionally filtered by status
- `POST /goals` — create (required: `type`, `name`, `target_amount`; optional:
  `monthly_contribution`, `target_date`, `priority`, `emoji`, `notes`)
- `PUT /goals/:id` — update (all fields optional, incl. `current_amount`, `status`)
- `POST /goals/:id/contribute` — add `amount` to `current_amount`
- `DELETE /goals/:id` — delete

`current_amount` is NOT part of the create payload (starts at 0 via DB default).

## Architecture

Frontend-only. Mirror `app/lib/features/debts/`.

**Files:**
- `app/lib/features/goals/presentation/goals_screen.dart` — replace placeholder with
  the full list screen (mirrors `debts_screen.dart`).
- `app/lib/features/goals/presentation/add_goal_sheet.dart` — **new**, create/edit sheet
  (mirrors `add_debt_sheet.dart`).
- `app/lib/features/goals/presentation/contribute_sheet.dart` — **new**, small sheet to
  add a contribution (amount only).
- `app/lib/core/providers.dart` — add `allGoalsProvider` (FutureProvider, no status
  filter) for the list screen. The existing `goalsProvider` (active-only) stays for the
  dashboard mini-card.

**Reused as-is:** `Goal` (domain), `goal_repository.dart` (`getGoals`, `addGoal`,
`updateGoal`, `addContribution`, `deleteGoal`), `goalRepositoryProvider`.

## Goal Types (fixed list with emoji)

| Label | emoji | type value |
|---|---|---|
| Fondo de emergencia | 🛟 | `emergency_fund` |
| Ahorro | 💰 | `savings` |
| Viaje | ✈️ | `travel` |
| Casa | 🏠 | `house` |
| Auto | 🚗 | `car` |
| Educación | 🎓 | `education` |
| Retiro | 🌴 | `retirement` |
| Otro | 🎯 | `other` |

The emoji is saved to the `emoji` field, the type value to `type`. The card shows the
emoji + name.

## GoalsScreen (mirrors DebtsScreen)

- Header with back button + title "Metas".
- Filter chips: `Activas` / `Completadas` / `Todas`.
- Goal cards (`_GoalRow`): emoji + name, priority badge (Alta/Media/Baja), a
  `✓ Lograda` badge when completed, progress bar, "$current / $target (X%)", target
  date if present ("faltan N meses" or the date), and a **"+ Abonar"** button. Tapping
  the card (outside the button) opens the edit sheet.
- Empty state / error state / pull-to-refresh (mirrors debts).
- FAB "Nueva meta" → `add_goal_sheet`.
- Bottom summary bar (`_SummaryBar`): TOTAL AHORRADO + TOTAL OBJETIVO (sum of goals in
  the current filter).

## Sheets

**add_goal_sheet (create/edit):** type selector (emoji grid), Nombre, Monto objetivo,
Fecha objetivo (optional date picker), Aporte mensual (optional), Prioridad
(Alta/Media/Baja → 3/2/1), Notas. Edit mode adds a delete button. The current amount is
NOT edited here — it is managed via "+ Abonar"; on create it starts at 0.

Priority mapping: Alta = 3, Media = 2, Baja = 1 (default Media/2).

**contribute_sheet (abonar):** shows the goal + current progress, a single "Monto a
abonar" field, confirm button → `addContribution(id, amount)`. If the new total
(`currentAmount + amount`) ≥ `targetAmount`, also send `updateGoal(id, {status:
'completed'})`.

## Data Flow

- `allGoalsProvider` (FutureProvider, no status filter) feeds the list; filtered
  client-side by the chips (active / completed / all).
- After any mutation (create/edit/delete/contribute/complete), invalidate
  `allGoalsProvider`, `goalsProvider` (dashboard active-only), and
  `dashboardSummaryProvider` — same as debts.
- Contribute: `addContribution(id, amount)` → if `currentAmount + amount >=
  targetAmount`, chain `updateGoal(id, {status: 'completed'})` → then invalidate.

## Error Handling

- `.when(loading/error/data)` on the list (spinner / "No pudimos cargar tus metas" /
  content).
- Sheet validation: name and target amount required; amounts > 0; contribution amount
  > 0. SnackBar on mutation network failure (mirrors debts).

## Testing

No automated tests by project convention (same as debts). Verification:
- `flutter analyze` clean on `lib/features/goals`.
- Manual device test (Android): open Metas tab, create a goal, contribute (watch
  progress rise), contribute to 100% (see "Lograda" badge + Completadas filter), edit,
  delete, and confirm the dashboard Meta mini-card refreshes.
