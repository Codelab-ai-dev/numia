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
