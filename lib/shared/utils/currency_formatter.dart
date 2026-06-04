import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _mxn = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 0,
  );

  static final _mxnDecimals = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );

  /// Formato: $142,800
  static String formatMXN(double amount) => _mxn.format(amount);

  /// Formato: $142,800.50
  static String formatMXNDecimals(double amount) => _mxnDecimals.format(amount);

  /// Formato: +$4,200 o -$1,240
  static String formatDelta(double amount) {
    final prefix = amount >= 0 ? '+' : '';
    return '$prefix${formatMXN(amount)}';
  }

  /// Formato: 12.4%
  static String formatPct(double pct) =>
      '${pct.toStringAsFixed(1)}%';
}
