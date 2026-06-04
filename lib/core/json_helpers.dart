/// Safely converts a JSON value (num or String from pgtype.Numeric) to double.
double toDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

/// Safely converts a JSON value to double, returning null for null input.
double? toDoubleOrNull(dynamic v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
