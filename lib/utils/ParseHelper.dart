// utils/parsers.dart
class ParseHelper {
  static num? toNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      final parsed = num.tryParse(value);
      if (parsed != null) return parsed;
      // Pour les montants comme "1 000 000" ou "1,000,000"
      final cleaned = value.replaceAll(RegExp(r'[^\d.-]'), '');
      return num.tryParse(cleaned);
    }
    return null;
  }
  
  static double toDouble(dynamic value, {double defaultValue = 0}) {
    final numValue = toNum(value);
    return numValue?.toDouble() ?? defaultValue;
  }
  
  static int toInt(dynamic value, {int defaultValue = 0}) {
    final numValue = toNum(value);
    return numValue?.toInt() ?? defaultValue;
  }
}