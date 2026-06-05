# Escanear Ticket → Gasto (Scan Receipt to Expense) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user photograph a receipt/invoice/note and auto-create an expense from AI-extracted data, which they review and confirm in the existing "Agregar gasto" sheet.

**Architecture:** A new backend endpoint `POST /api/v1/budget/expenses/scan` sends a base64 image to Groq vision (`llama-4-scout-17b-16e-instruct`) with the user's category list, parses a strict JSON result, maps the category name to a real id (fallback "Otros"), and returns structured data. The Flutter app picks an image (camera/gallery) with `image_picker`, base64-encodes it, POSTs it, then opens the existing add-expense sheet **prefilled and editable**.

**Tech Stack:** Go (Gin, sqlc, pgx/v5), Groq OpenAI-compatible vision API, Flutter (Riverpod, Dio, image_picker).

**Reference spec:** `docs/superpowers/specs/2026-06-05-scan-receipt-design.md`

**Project verification convention:** No automated tests. Verify with `flutter analyze`, `go build ./...`, `go vet ./...`, and a manual device test. Each task ends in a build/analyze verification + commit.

---

## Backend (Go) — work from `api/`

### Task 1: Groq vision client (`VisionJSON`)

**Files:**
- Create: `api/internal/coach/groq_vision.go`

This adds a **non-streaming** method on the existing `coach.GroqClient` that sends an image data URL + a text prompt and returns the raw JSON string the model produces. It reuses `groqAPIURL`, `g.apiKey`, and `g.httpClient` already defined in `api/internal/coach/groq.go`. It is kept separate from `StreamChat` so the coach chat (SSE, text-only) is untouched.

- [ ] **Step 1: Create the vision client file**

Create `api/internal/coach/groq_vision.go`:

```go
package coach

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

const groqVisionModel = "llama-4-scout-17b-16e-instruct"

// visionImageURL is the image_url payload (a data URL with base64 content).
type visionImageURL struct {
	URL string `json:"url"`
}

// visionContentPart is one item in a multimodal message content array.
type visionContentPart struct {
	Type     string          `json:"type"`
	Text     string          `json:"text,omitempty"`
	ImageURL *visionImageURL `json:"image_url,omitempty"`
}

// visionMessage is a chat message whose content is an array of parts.
type visionMessage struct {
	Role    string              `json:"role"`
	Content []visionContentPart `json:"content"`
}

// visionResponseFormat forces a JSON object response.
type visionResponseFormat struct {
	Type string `json:"type"`
}

// visionRequest is the request body for a non-streaming vision call.
type visionRequest struct {
	Model          string               `json:"model"`
	Messages       []visionMessage      `json:"messages"`
	ResponseFormat visionResponseFormat `json:"response_format"`
	Stream         bool                 `json:"stream"`
}

// visionResponse is the relevant subset of the chat completion response.
type visionResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

// VisionJSON sends an image (as a data URL) plus a prompt to the Groq vision
// model and returns the raw JSON string the model produces. Non-streaming.
func (g *GroqClient) VisionJSON(ctx context.Context, prompt, imageDataURL string) (string, error) {
	reqBody := visionRequest{
		Model: groqVisionModel,
		Messages: []visionMessage{
			{
				Role: "user",
				Content: []visionContentPart{
					{Type: "text", Text: prompt},
					{Type: "image_url", ImageURL: &visionImageURL{URL: imageDataURL}},
				},
			},
		},
		ResponseFormat: visionResponseFormat{Type: "json_object"},
		Stream:         false,
	}

	bodyBytes, err := json.Marshal(reqBody)
	if err != nil {
		return "", fmt.Errorf("marshal vision request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, groqAPIURL, bytes.NewReader(bodyBytes))
	if err != nil {
		return "", fmt.Errorf("create vision request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+g.apiKey)

	resp, err := g.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("vision http request: %w", err)
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("groq vision api error %d: %s", resp.StatusCode, string(body))
	}

	var vr visionResponse
	if err := json.Unmarshal(body, &vr); err != nil {
		return "", fmt.Errorf("unmarshal vision response: %w", err)
	}
	if len(vr.Choices) == 0 {
		return "", fmt.Errorf("vision response had no choices")
	}
	return vr.Choices[0].Message.Content, nil
}
```

- [ ] **Step 2: Verify it builds**

Run (from `api/`): `go build ./...`
Expected: builds cleanly, no errors.

- [ ] **Step 3: Verify vet**

Run (from `api/`): `go vet ./internal/coach/...`
Expected: no output (clean).

- [ ] **Step 4: Commit**

```bash
git add api/internal/coach/groq_vision.go
git commit -m "feat: add non-streaming Groq VisionJSON client method"
```

---

### Task 2: Budget service `ScanReceipt` + wiring

**Files:**
- Modify: `api/internal/budget/service.go`
- Modify: `api/cmd/api/main.go`

This adds the request/response types, a small `VisionClient` interface (so `budget` does not import `coach`), a `vision` field on `Service`, the `ScanReceipt` method, and updates `NewService` + `main.go` so everything compiles in one commit.

- [ ] **Step 1: Add imports to `service.go`**

In `api/internal/budget/service.go`, the current import block is:

```go
import (
	"context"
	"fmt"
	"log"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)
```

Replace it with (adds `encoding/json` and `strings`):

```go
import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"numia-api/internal/database/sqlc"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)
```

- [ ] **Step 2: Add the scan request/response types**

In `api/internal/budget/service.go`, immediately after the `CreateExpenseRequest` struct (the block ending with the closing `}` of `CreateExpenseRequest`, around line 69), add:

```go
// ScanReceiptRequest is the payload for scanning a receipt image.
type ScanReceiptRequest struct {
	ImageBase64 string `json:"image_base64" binding:"required"`
}

// ScanResult is the structured data extracted from a receipt image. Every
// field may be null; the app still opens the prefilled form.
type ScanResult struct {
	Amount       *float64 `json:"amount"`
	ExpenseDate  *string  `json:"expense_date"`
	Description  *string  `json:"description"`
	Subcategory  *string  `json:"subcategory"`
	CategoryID   *string  `json:"category_id"`
	CategoryName *string  `json:"category_name"`
}

// visionExtract is the raw JSON shape we ask the vision model to return.
type visionExtract struct {
	Amount   *float64 `json:"amount"`
	Date     *string  `json:"date"`
	Merchant *string  `json:"merchant"`
	Category *string  `json:"category"`
}

// VisionClient extracts structured JSON from an image. Implemented by
// coach.GroqClient via VisionJSON; declared here to avoid importing coach.
type VisionClient interface {
	VisionJSON(ctx context.Context, prompt, imageDataURL string) (string, error)
}
```

- [ ] **Step 3: Add the `vision` field and update `NewService`**

In `api/internal/budget/service.go`, the current Service struct and constructor are:

```go
// Service provides budget-related business logic.
type Service struct {
	q   *sqlc.Queries
	fcm *FCMClient
}

// NewService creates a new budget Service.
func NewService(q *sqlc.Queries, fcm *FCMClient) *Service {
	return &Service{q: q, fcm: fcm}
}
```

Replace with:

```go
// Service provides budget-related business logic.
type Service struct {
	q      *sqlc.Queries
	fcm    *FCMClient
	vision VisionClient
}

// NewService creates a new budget Service.
func NewService(q *sqlc.Queries, fcm *FCMClient, vision VisionClient) *Service {
	return &Service{q: q, fcm: fcm, vision: vision}
}
```

- [ ] **Step 4: Add the `ScanReceipt` method + prompt builder**

In `api/internal/budget/service.go`, add at the end of the file (after `uuidString`):

```go
// buildScanPrompt builds the vision prompt that lists the user's category
// names and asks for a strict JSON object.
func buildScanPrompt(categoryNames []string) string {
	cats := strings.Join(categoryNames, ", ")
	return fmt.Sprintf(`Eres un asistente que extrae datos de tickets, facturas o notas escritas a mano.
Analiza la imagen y devuelve UNICAMENTE un objeto JSON valido con esta forma exacta:
{"amount": number|null, "date": "YYYY-MM-DD"|null, "merchant": string|null, "category": string|null}

Reglas:
- "amount": el total a pagar como numero, sin simbolo de moneda. Si no es legible, null.
- "date": la fecha del ticket en formato YYYY-MM-DD. Si no hay fecha, null.
- "merchant": el nombre del comercio o una descripcion breve. Si no se distingue, null.
- "category": elige EXACTAMENTE una de estas categorias: %s. Si ninguna aplica, usa "Otros".
- No incluyas texto adicional, explicaciones ni markdown. Solo el objeto JSON.`, cats)
}

// ScanReceipt sends a base64 image to the vision model, parses the result, and
// maps the extracted category name to a real category id (fallback "Otros").
func (s *Service) ScanReceipt(ctx context.Context, userID uuid.UUID, imageBase64 string) (ScanResult, error) {
	cats, err := s.ListCategories(ctx, userID)
	if err != nil {
		return ScanResult{}, fmt.Errorf("list categories: %w", err)
	}

	names := make([]string, 0, len(cats))
	byLowerName := make(map[string]sqlc.BudgetCategory, len(cats))
	var otros *sqlc.BudgetCategory
	for i := range cats {
		names = append(names, cats[i].Name)
		byLowerName[strings.ToLower(cats[i].Name)] = cats[i]
		if cats[i].Name == "Otros" {
			otros = &cats[i]
		}
	}

	raw, err := s.vision.VisionJSON(ctx, buildScanPrompt(names), "data:image/jpeg;base64,"+imageBase64)
	if err != nil {
		return ScanResult{}, fmt.Errorf("vision: %w", err)
	}

	var ext visionExtract
	if err := json.Unmarshal([]byte(raw), &ext); err != nil {
		return ScanResult{}, fmt.Errorf("parse vision json: %w", err)
	}

	result := ScanResult{
		Amount:      ext.Amount,
		ExpenseDate: ext.Date,
		Description: ext.Merchant,
	}

	var matched *sqlc.BudgetCategory
	if ext.Category != nil {
		if c, ok := byLowerName[strings.ToLower(strings.TrimSpace(*ext.Category))]; ok {
			matched = &c
		}
	}
	if matched == nil {
		matched = otros
	}
	if matched != nil {
		id := uuidString(matched.ID)
		name := matched.Name
		result.CategoryID = &id
		result.CategoryName = &name
	}

	return result, nil
}
```

- [ ] **Step 5: Update `main.go` to pass the vision client**

In `api/cmd/api/main.go`, the Coach and Budget wiring is:

```go
	// Coach
	groqClient := coach.NewGroqClient(cfg.GroqAPIKey)
	coachService := coach.NewService(queries, groqClient)
	coachHandler := coach.NewHandler(coachService)
	coachHandler.RegisterRoutes(protected)

	// Budget
	fcmClient := budget.NewFCMClient(cfg.FirebaseCredentialsPath)
	budgetService := budget.NewService(queries, fcmClient)
	budgetHandler := budget.NewHandler(budgetService)
	budgetHandler.RegisterRoutes(protected)
```

Change the budget service line to pass `groqClient` (already in scope from the Coach block; `*coach.GroqClient` satisfies `budget.VisionClient`):

```go
	// Budget
	fcmClient := budget.NewFCMClient(cfg.FirebaseCredentialsPath)
	budgetService := budget.NewService(queries, fcmClient, groqClient)
	budgetHandler := budget.NewHandler(budgetService)
	budgetHandler.RegisterRoutes(protected)
```

- [ ] **Step 6: Verify it builds**

Run (from `api/`): `go build ./...`
Expected: builds cleanly.

- [ ] **Step 7: Verify vet**

Run (from `api/`): `go vet ./...`
Expected: no output (clean).

- [ ] **Step 8: Commit**

```bash
git add api/internal/budget/service.go api/cmd/api/main.go
git commit -m "feat: add budget ScanReceipt service with Groq vision"
```

---

### Task 3: Scan endpoint (handler + route)

**Files:**
- Modify: `api/internal/budget/handler.go`

- [ ] **Step 1: Register the route**

In `api/internal/budget/handler.go`, the Expenses route block in `RegisterRoutes` is:

```go
	// Expenses
	g.GET("/expenses", h.listExpenses)
	g.POST("/expenses", h.createExpense)
	g.PUT("/expenses/:id", h.updateExpense)
	g.DELETE("/expenses/:id", h.deleteExpense)
```

Replace with (adds the scan route):

```go
	// Expenses
	g.GET("/expenses", h.listExpenses)
	g.POST("/expenses", h.createExpense)
	g.POST("/expenses/scan", h.scanReceipt)
	g.PUT("/expenses/:id", h.updateExpense)
	g.DELETE("/expenses/:id", h.deleteExpense)
```

- [ ] **Step 2: Add the handler method**

In `api/internal/budget/handler.go`, after the `createExpense` handler method (ends around line 162), add:

```go
func (h *Handler) scanReceipt(c *gin.Context) {
	var req ScanReceiptRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		middleware.RespondError(c, http.StatusBadRequest, "VALIDATION_ERROR", err.Error())
		return
	}
	userID := middleware.GetUserID(c)
	result, err := h.s.ScanReceipt(c.Request.Context(), userID, req.ImageBase64)
	if err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"error": "No pudimos leer el ticket"})
		return
	}
	c.JSON(http.StatusOK, result)
}
```

- [ ] **Step 3: Verify build + vet**

Run (from `api/`): `go build ./... && go vet ./...`
Expected: builds cleanly, no vet output.

- [ ] **Step 4: Commit**

```bash
git add api/internal/budget/handler.go
git commit -m "feat: add POST /budget/expenses/scan endpoint"
```

---

## Frontend (Flutter) — work from `app/`

### Task 4: Add `image_picker` dependency

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Step 1: Add the dependency**

In `app/pubspec.yaml`, the file-picker dependency block is:

```yaml
  # File picker (PDF estados de cuenta)
  file_picker: ^8.0.3
```

Add directly below it:

```yaml
  # Image picker (escanear tickets: cámara + galería)
  image_picker: ^1.1.2
```

- [ ] **Step 2: Resolve dependencies**

Run (from `app/`): `flutter pub get`
Expected: "Got dependencies!" with `image_picker` resolved.

- [ ] **Step 3: Commit**

```bash
git add app/pubspec.yaml app/pubspec.lock
git commit -m "chore: add image_picker dependency"
```

---

### Task 5: Platform permissions

**Files:**
- Modify: `app/android/app/src/main/AndroidManifest.xml`
- Modify: `app/ios/Runner/Info.plist`

- [ ] **Step 1: Add the Android camera permission**

In `app/android/app/src/main/AndroidManifest.xml`, the file opens with:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application
```

Insert a `<uses-permission>` line between `<manifest ...>` and `<application`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA"/>
    <application
```

- [ ] **Step 2: Add the iOS usage descriptions**

In `app/ios/Runner/Info.plist`, find the closing of the dict (the last two keys are `UIApplicationSupportsIndirectInputEvents` / `<true/>` followed by `</dict>`):

```xml
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
</dict>
```

Replace with (adds the two camera/photo usage strings before `</dict>`):

```xml
	<key>UIApplicationSupportsIndirectInputEvents</key>
	<true/>
	<key>NSCameraUsageDescription</key>
	<string>Numia usa la cámara para escanear tus tickets y registrar gastos automáticamente.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Numia accede a tus fotos para escanear tickets desde tu galería.</string>
</dict>
```

- [ ] **Step 3: Commit**

```bash
git add app/android/app/src/main/AndroidManifest.xml app/ios/Runner/Info.plist
git commit -m "feat: add camera and photo-library permissions for receipt scanning"
```

---

### Task 6: `ScanResult` domain model

**Files:**
- Create: `app/lib/features/budget/domain/scan_result.dart`

- [ ] **Step 1: Create the model**

Create `app/lib/features/budget/domain/scan_result.dart`:

```dart
import '../../../core/json_helpers.dart';

/// Structured data extracted from a scanned receipt. Every field may be null;
/// the prefill form still opens so the user can complete it.
class ScanResult {
  final double? amount;
  final DateTime? expenseDate;
  final String? description;
  final String? subcategory;
  final String? categoryId;
  final String? categoryName;

  const ScanResult({
    this.amount,
    this.expenseDate,
    this.description,
    this.subcategory,
    this.categoryId,
    this.categoryName,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    final dateStr = json['expense_date'] as String?;
    return ScanResult(
      amount: toDoubleOrNull(json['amount']),
      expenseDate: dateStr != null ? DateTime.tryParse(dateStr) : null,
      description: json['description'] as String?,
      subcategory: json['subcategory'] as String?,
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
    );
  }
}
```

- [ ] **Step 2: Verify analyze**

Run (from `app/`): `flutter analyze lib/features/budget/domain/scan_result.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/budget/domain/scan_result.dart
git commit -m "feat: add ScanResult domain model"
```

---

### Task 7: Repository `scanReceipt` method

**Files:**
- Modify: `app/lib/features/budget/data/budget_repository.dart`

- [ ] **Step 1: Import the model**

In `app/lib/features/budget/data/budget_repository.dart`, the import block is:

```dart
import '../../../core/api_client.dart';
import '../domain/budget.dart';
import '../domain/budget_category.dart';
import '../domain/budget_summary.dart';
import '../domain/expense.dart';
```

Add the scan_result import:

```dart
import '../../../core/api_client.dart';
import '../domain/budget.dart';
import '../domain/budget_category.dart';
import '../domain/budget_summary.dart';
import '../domain/expense.dart';
import '../domain/scan_result.dart';
```

- [ ] **Step 2: Add the method**

In the same file, after the `createExpense` method (ends around line 82), add:

```dart
  Future<ScanResult> scanReceipt(String imageBase64) async {
    final response = await _client.dio.post(
      '/api/v1/budget/expenses/scan',
      data: {'image_base64': imageBase64},
    );
    return ScanResult.fromJson(response.data as Map<String, dynamic>);
  }
```

- [ ] **Step 3: Verify analyze**

Run (from `app/`): `flutter analyze lib/features/budget/data/budget_repository.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/budget/data/budget_repository.dart
git commit -m "feat: add scanReceipt repository method"
```

---

### Task 8: Prefill params on `AddExpenseSheet`

**Files:**
- Modify: `app/lib/features/budget/presentation/add_expense_sheet.dart`

This adds optional prefill params used **only in create mode** (when not editing). Save logic is unchanged.

- [ ] **Step 1: Add the prefill fields + constructor params**

In `app/lib/features/budget/presentation/add_expense_sheet.dart`, the widget declaration is:

```dart
class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({super.key, this.onSaved, this.expense});

  final VoidCallback? onSaved;
  final Expense? expense;

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}
```

Replace with:

```dart
class AddExpenseSheet extends ConsumerStatefulWidget {
  const AddExpenseSheet({
    super.key,
    this.onSaved,
    this.expense,
    this.prefillAmount,
    this.prefillDate,
    this.prefillDescription,
    this.prefillSubcategory,
    this.prefillCategoryId,
  });

  final VoidCallback? onSaved;
  final Expense? expense;

  // Prefill values (used only in create mode, e.g. from a scanned receipt).
  final double? prefillAmount;
  final DateTime? prefillDate;
  final String? prefillDescription;
  final String? prefillSubcategory;
  final String? prefillCategoryId;

  @override
  ConsumerState<AddExpenseSheet> createState() => _AddExpenseSheetState();
}
```

- [ ] **Step 2: Apply prefills in `initState`**

In the same file, the current `initState` is:

```dart
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
```

Replace with (adds an `else` branch applying the prefills):

```dart
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
    } else {
      if (widget.prefillAmount != null) {
        _amountController.text = widget.prefillAmount!.toStringAsFixed(2);
      }
      _descriptionController.text = widget.prefillDescription ?? '';
      _subcategoryController.text = widget.prefillSubcategory ?? '';
      _selectedCategoryId = widget.prefillCategoryId;
      if (widget.prefillDate != null) {
        _selectedDate = widget.prefillDate!;
      }
    }
    _loadCategories();
  }
```

- [ ] **Step 3: Verify analyze**

Run (from `app/`): `flutter analyze lib/features/budget/presentation/add_expense_sheet.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/budget/presentation/add_expense_sheet.dart
git commit -m "feat: support prefill values in AddExpenseSheet create mode"
```

---

### Task 9: Scan action orchestrator

**Files:**
- Create: `app/lib/features/budget/presentation/scan_receipt_action.dart`

This is the function the budget screen calls: it shows a Cámara/Galería mini sheet, picks + compresses the image, base64-encodes it, shows a blocking loader, calls `scanReceipt`, and opens the prefilled `AddExpenseSheet`. On 422 it shows the error and opens the empty form; on network errors it shows a connectivity message.

- [ ] **Step 1: Create the file**

Create `app/lib/features/budget/presentation/scan_receipt_action.dart`:

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../shared/constants/n_colors.dart';
import '../../../shared/constants/n_spacing.dart';
import '../../../shared/constants/n_typography.dart';
import '../domain/scan_result.dart';
import 'add_expense_sheet.dart';

/// Entry point for the "Escanear ticket" flow: pick an image (camera/gallery),
/// send it to the backend for OCR, then open the prefilled add-expense sheet.
Future<void> scanReceiptAndAddExpense(
    BuildContext context, WidgetRef ref) async {
  final source = await _pickSource(context);
  if (source == null) return;

  final picker = ImagePicker();
  XFile? file;
  try {
    file = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 70,
    );
  } catch (_) {
    if (!context.mounted) return;
    _snack(context, 'Activa el permiso de cámara para escanear');
    return;
  }
  if (file == null) return; // user cancelled

  final bytes = await file.readAsBytes();
  final imageBase64 = base64Encode(bytes);

  if (!context.mounted) return;
  _showLoader(context);

  ScanResult? result;
  try {
    result = await ref.read(budgetRepositoryProvider).scanReceipt(imageBase64);
  } on DioException catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss loader
    if (e.response?.statusCode == 422) {
      _snack(context, 'No pudimos leer el ticket');
      _openExpenseSheet(context, ref, null);
    } else {
      _snack(context, 'Sin conexión, intenta de nuevo');
    }
    return;
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss loader
    _snack(context, 'Sin conexión, intenta de nuevo');
    return;
  }

  if (!context.mounted) return;
  Navigator.of(context).pop(); // dismiss loader
  _openExpenseSheet(context, ref, result);
}

Future<ImageSource?> _pickSource(BuildContext context) {
  final ct = NColorTheme.of(context);
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: ct.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NSpacing.rXl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
          NSpacing.pageH, NSpacing.sp4, NSpacing.pageH, NSpacing.sp6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ct.borderDefault,
              borderRadius: BorderRadius.circular(NSpacing.rFull),
            ),
          ),
          const SizedBox(height: NSpacing.sp4),
          ListTile(
            leading: Icon(Icons.camera_alt_rounded, color: ct.accent1),
            title: Text('Cámara',
                style: NTypography.title.copyWith(color: ct.textPrimary)),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          ListTile(
            leading: Icon(Icons.photo_library_rounded, color: ct.accent1),
            title: Text('Galería',
                style: NTypography.title.copyWith(color: ct.textPrimary)),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

void _showLoader(BuildContext context) {
  final ct = NColorTheme.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: Container(
        padding: const EdgeInsets.all(NSpacing.sp5),
        decoration: BoxDecoration(
          color: ct.surface1,
          borderRadius: BorderRadius.circular(NSpacing.rXl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: NSpacing.sp4),
            Text('Leyendo ticket…',
                style: NTypography.body.copyWith(color: ct.textPrimary)),
          ],
        ),
      ),
    ),
  );
}

void _openExpenseSheet(
    BuildContext context, WidgetRef ref, ScanResult? result) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddExpenseSheet(
      onSaved: () {
        ref.invalidate(budgetSummaryProvider);
        ref.invalidate(expensesProvider);
      },
      prefillAmount: result?.amount,
      prefillDate: result?.expenseDate,
      prefillDescription: result?.description,
      prefillSubcategory: result?.subcategory,
      prefillCategoryId: result?.categoryId,
    ),
  );
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
```

- [ ] **Step 2: Verify analyze**

Run (from `app/`): `flutter analyze lib/features/budget/presentation/scan_receipt_action.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add app/lib/features/budget/presentation/scan_receipt_action.dart
git commit -m "feat: add scanReceiptAndAddExpense orchestration flow"
```

---

### Task 10: "Escanear ticket" button on the budget screen

**Files:**
- Modify: `app/lib/features/budget/presentation/budget_screen.dart`

This replaces the single add FAB with a small "scan" FAB stacked above the existing add FAB.

- [ ] **Step 1: Import the scan action**

In `app/lib/features/budget/presentation/budget_screen.dart`, the local imports near the top include:

```dart
import 'budget_setup_screen.dart';
import 'add_expense_sheet.dart';
import 'category_detail_screen.dart';
```

Add the scan action import:

```dart
import 'budget_setup_screen.dart';
import 'add_expense_sheet.dart';
import 'category_detail_screen.dart';
import 'scan_receipt_action.dart';
```

- [ ] **Step 2: Replace the FAB with a stacked scan + add pair**

In the same file, the `BudgetScreen.build` currently ends with:

```dart
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openExpenseSheet(context, ref),
        backgroundColor: ct.accent1,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
```

Replace with:

```dart
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scanReceipt',
            onPressed: () => scanReceiptAndAddExpense(context, ref),
            backgroundColor: ct.surface2,
            child: Icon(Icons.document_scanner_rounded, color: ct.accent1),
          ),
          const SizedBox(height: NSpacing.sp3),
          FloatingActionButton(
            heroTag: 'addExpense',
            onPressed: () => _openExpenseSheet(context, ref),
            backgroundColor: ct.accent1,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify analyze**

Run (from `app/`): `flutter analyze lib/features/budget`
Expected: only the 4 pre-existing info-level `prefer_const_constructors` lints in `budget_screen.dart` (unrelated to this work); no new warnings/errors from the scan feature.

- [ ] **Step 4: Commit**

```bash
git add app/lib/features/budget/presentation/budget_screen.dart
git commit -m "feat: add Escanear ticket button to budget screen"
```

---

### Task 11: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Backend build + vet**

Run (from `api/`): `go build ./... && go vet ./...`
Expected: builds cleanly, no vet output.

- [ ] **Step 2: Frontend analyze**

Run (from `app/`): `flutter analyze lib/features/budget`
Expected: no new issues from the scan feature (only the 4 pre-existing info lints may remain).

- [ ] **Step 3: Manual device test (Android)**

1. Run the app on the connected device (`flutter run`).
2. Go to Presupuesto → tap the new scan FAB → choose **Cámara** → photograph a real receipt.
3. Confirm the loader "Leyendo ticket…" appears, then the add-expense sheet opens **prefilled** with amount/date/category.
4. Correct anything needed → save → confirm the expense appears and the summary updates.
5. Repeat from **Galería**.
6. Scan an unreadable photo → confirm it falls back to the **empty** manual form with the "No pudimos leer el ticket" snackbar.

- [ ] **Step 4: Final review**

Dispatch the final code reviewer for the whole implementation, then use superpowers:finishing-a-development-branch.

---

## Self-Review Notes

- **Spec coverage:** Endpoint (Task 3), service `ScanReceipt` (Task 2), vision client `VisionJSON` (Task 1), `image_picker` dep (Task 4), permissions (Task 5), `scan_result.dart` (Task 6), repo `scanReceipt` (Task 7), `add_expense_sheet` prefill (Task 8), `scan_receipt_action.dart` (Task 9), budget-screen button (Task 10), error handling (in Task 9: 422→empty form + snackbar, network→snackbar, cancel→silent, permission→snackbar), verification (Task 11). All spec sections mapped.
- **Type consistency:** Backend `ScanResult` JSON fields (`amount`, `expense_date`, `description`, `subcategory`, `category_id`, `category_name`) match `ScanResult.fromJson` on the Dart side. Vision model returns `{amount,date,merchant,category}` (`visionExtract`) which the service maps into `ScanResult`. `VisionJSON(ctx, prompt, imageDataURL)` signature matches the `budget.VisionClient` interface and is satisfied by `coach.GroqClient`.
- **Design deviation from spec (justified):** The spec text suggested `budget` reuse the coach client directly; this plan introduces a tiny `budget.VisionClient` interface so `budget` does not import `coach`, avoiding package coupling while satisfying the same behavior. `main.go` passes the existing `groqClient`, which implements the interface.
