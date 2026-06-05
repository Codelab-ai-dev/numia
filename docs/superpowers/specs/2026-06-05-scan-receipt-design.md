# Escanear Ticket → Gasto (Scan Receipt to Expense) — Design Spec

**Date:** 2026-06-05
**Status:** Approved

## Overview

Add a feature that lets the user **photograph a receipt, invoice, or handwritten
note** and have the app **auto-create an expense** from the data extracted by an AI
vision model. The user reviews and corrects the prefilled data before saving.

This spans **backend + frontend** but is one cohesive feature, so a single spec/plan.

## Decisions (from brainstorming)

- **OCR/extraction engine:** Backend, using **Groq vision** (same provider already used
  by the coach). Keeps the API key server-side and the category-mapping logic in one
  place.
- **Post-scan flow:** Open the existing "Agregar gasto" sheet **prefilled and editable**.
  The user confirms before anything is saved.
- **Image source:** **Camera + Gallery** (via `image_picker`).
- **Entry point:** A **"Escanear ticket" button on the Budget screen**, next to the
  existing "Agregar gasto".
- **Image transport:** **base64 inside JSON** (no multipart) — simplest, matches
  existing JSON patterns, no HTTP-client changes.

## Architecture & Data Flow

1. Budget screen → "Escanear ticket" → mini action sheet (Cámara / Galería).
2. `image_picker` captures the image and **compresses it on-device** (`maxWidth` +
   `imageQuality`) to keep the payload small.
3. App base64-encodes the bytes and POSTs to `POST /api/v1/budget/expenses/scan`
   (JSON, existing Bearer auth). A blocking loader shows "Leyendo ticket…".
4. Backend sends the image to Groq vision (`llama-4-scout-17b-16e-instruct`) together
   with the **user's category list**, asking for a **strict JSON**: amount, date,
   merchant/description, best-matching category.
5. Backend resolves the category name → real `category_id` (fallback to "Otros" if no
   clear match) and returns the structured data.
6. App opens the **prefilled "Agregar gasto" sheet**. User reviews/corrects, confirms
   → uses the existing `POST /budget/expenses`.

## Backend (Go)

### Endpoint
`POST /api/v1/budget/expenses/scan` (JWT-protected, in `internal/budget/handler.go`).

- Request: `{ "image_base64": "<base64 string, no data-url prefix>" }`
- Response 200:
  ```json
  {
    "amount": 250.50,
    "expense_date": "2026-06-05",
    "description": "Restaurante La Parrilla",
    "subcategory": null,
    "category_id": "<uuid>",
    "category_name": "Alimentacion"
  }
  ```
  Any field may be `null` (except the object itself). `amount` null is allowed — the
  app still opens the form.
- Response 422: `{ "error": "No pudimos leer el ticket" }` when the model returns
  invalid JSON or the image is unreadable.

### Service
`internal/budget/service.go` → `ScanReceipt(userID, imageBase64) (ScanResult, error)`:

1. Load the user's categories (reuse the same query as `GetCategories`).
2. Call Groq vision with a prompt that includes the category **names** and asks for a
   JSON object with: `amount` (number or null), `date` (`YYYY-MM-DD` or null),
   `merchant` (string or null), `category` (one of the given names or empty).
3. Parse the JSON. Map `merchant` → `description`; map `category` (name) → real
   `category_id`. If no match, use the **"Otros"** category id. If amount missing,
   leave `null`.
4. Return the struct. If JSON parsing fails, return an error → handler responds 422.

### Vision client
In `internal/coach/groq.go` (or a new `groq_vision.go`), add a **non-streaming**
method `VisionJSON(prompt, imageDataURL) (string, error)` that:
- Builds a message with `content` array: an `image_url` part (data URL with base64) +
  a `text` part (the prompt).
- Sets `response_format: { "type": "json_object" }`.
- Uses model `llama-4-scout-17b-16e-instruct`.
- Reuses `GROQ_API_KEY` and the existing `http.Client`. Returns the JSON string.

Kept separate from `StreamChat` (text-only, SSE) so each function has one clear
responsibility; the coach chat is untouched.

## Frontend (Flutter)

### Dependency
Add `image_picker` to `app/pubspec.yaml` (covers camera + gallery, with compression
via `maxWidth`/`imageQuality`).

### Permissions
- Android `android/app/src/main/AndroidManifest.xml`:
  `<uses-permission android:name="android.permission.CAMERA"/>`
- iOS `app/ios/Runner/Info.plist`: `NSCameraUsageDescription` and
  `NSPhotoLibraryUsageDescription` (Spanish copy).

### Files
- **New** `app/lib/features/budget/domain/scan_result.dart`: model with `amount?`
  (double), `expenseDate?` (DateTime), `description?` (String), `subcategory?`
  (String), `categoryId?` (String), `categoryName?` (String) + `fromJson`.
- **Modify** `app/lib/features/budget/data/budget_repository.dart`: add
  `Future<ScanResult> scanReceipt(String imageBase64)` → POST to
  `/api/v1/budget/expenses/scan`.
- **New** `app/lib/features/budget/presentation/scan_receipt_action.dart`: function
  `scanReceiptAndAddExpense(BuildContext, WidgetRef)` that:
  1. shows a mini sheet "Cámara / Galería",
  2. picks the image with `image_picker` (compressed) and base64-encodes it,
  3. shows a blocking loader ("Leyendo ticket…"),
  4. calls `scanReceipt`,
  5. opens `AddExpenseSheet` prefilled with the `ScanResult`.
- **Modify** `app/lib/features/budget/presentation/add_expense_sheet.dart`: add optional
  **prefill** params (amount, date, description, subcategory, categoryId) used only in
  create mode. Save logic unchanged.
- **Modify** `app/lib/features/budget/presentation/budget_screen.dart`: add an
  **"Escanear ticket"** button next to "Agregar gasto", calling
  `scanReceiptAndAddExpense`. On save, invalidate `budgetSummaryProvider` and
  `expensesProvider` (existing pattern).

## Error Handling

- Camera permission denied / picker cancelled → SnackBar "Activa el permiso de cámara
  para escanear" (or silently do nothing on plain cancel).
- Unreadable image / invalid model JSON (422) → SnackBar "No pudimos leer el ticket" +
  open the **empty** manual form so the attempt isn't lost.
- Timeout / network → SnackBar "Sin conexión, intenta de nuevo" (Dio `receiveTimeout`
  is already 30s, enough for vision).
- Amount null but something was read → open the form with what was found; amount stays
  empty and required as it already is.

## Testing

Project convention: no automated tests. Verification:
- Frontend: `flutter analyze` clean on `lib/features/budget`.
- Backend: `go build ./...` and `go vet ./...` clean.
- Manual device test (Android): scan a real receipt (camera) → check amount/date/
  category prefill → correct & save; repeat from gallery; test an unreadable photo
  (must fall back to the manual form).
