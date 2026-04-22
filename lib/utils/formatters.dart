// utils/formatters.dart ou widgets/common_widgets.dart
import 'package:intl/intl.dart';

double parseMontant(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  if (value is String) {
    // Nettoie la chaîne (enlève les espaces, virgules, etc.)
    final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleaned) ?? 0;
  }
  return 0;
}

String formatMontant(dynamic montant) {
  final value = parseMontant(montant);
  final formatter = NumberFormat.currency(
    locale: 'fr_SN',
    symbol: 'FCFA',
    decimalDigits: 0,
  );
  return formatter.format(value);
}