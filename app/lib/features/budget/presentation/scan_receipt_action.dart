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
  if (!context.mounted) return;

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
    _snack(
      context,
      source == ImageSource.camera
          ? 'Activa el permiso de cámara para escanear'
          : 'Activa el permiso de fotos para escanear',
    );
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
