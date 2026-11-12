/// Parses user-entered page numbers (1-based) into zero-based PDF indices.
abstract final class PdfPageSelection {
  static String normalize(String input) {
    final translated = input.runes.map((c) {
      if (c >= 0x0660 && c <= 0x0669) return c - 0x0660 + 0x30;
      if (c >= 0x06f0 && c <= 0x06f9) return c - 0x06f0 + 0x30;
      if (c == 0x060c) return 0x2c;
      if (c >= 0x2010 && c <= 0x2014) return 0x2d;
      return c;
    });
    return String.fromCharCodes(translated);
  }

  static int page(String text, int pageCount) {
    if (pageCount < 1) throw ArgumentError.value(pageCount, 'pageCount');
    final value = normalize(text).trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      throw const FormatException('رقم الصفحة غير صحيح / Invalid page number');
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 1 || parsed > pageCount) {
      throw FormatException('رقم الصفحة يجب أن يكون بين 1 و $pageCount');
    }
    return parsed - 1;
  }

  /// Keeps the requested order while omitting duplicate pages.
  static List<int> parse(String text, int pageCount) {
    if (pageCount < 1) throw ArgumentError.value(pageCount, 'pageCount');
    final normalized = normalize(text).replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) {
      throw const FormatException('اكتب الصفحات مثل 1-3,5');
    }
    final indices = <int>[];
    final seen = <int>{};
    for (final token in normalized.split(',')) {
      final match = RegExp(r'^([0-9]+)(?:-([0-9]+))?$').firstMatch(token);
      if (match == null) throw FormatException('نطاق صفحات غير صحيح: $token');
      final first = page(match.group(1)!, pageCount);
      final last = match.group(2) == null
          ? first
          : page(match.group(2)!, pageCount);
      if (first > last) {
        throw FormatException('بداية النطاق بعد نهايته: $token');
      }
      for (var index = first; index <= last; index++) {
        if (seen.add(index)) indices.add(index);
      }
    }
    return indices;
  }
}
