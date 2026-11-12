import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/page_selection.dart';

void main() {
  group('PDF page selection', () {
    test('accepts Arabic-Indic numbers, Persian digits and Arabic comma', () {
      expect(PdfPageSelection.parse('١-٣،٥', 7), [0, 1, 2, 4]);
      expect(PdfPageSelection.parse('۳،١-٢،۳', 5), [2, 0, 1]);
      expect(PdfPageSelection.page('٧', 10), 6);
    });

    test('preserves selected order and removes duplicates', () {
      expect(PdfPageSelection.parse('5, 2-4, 2, 1', 6), [4, 1, 2, 3, 0]);
      expect(PdfPageSelection.parse('1–3,5', 5), [0, 1, 2, 4]);
    });

    test('rejects empty, reversed, malformed or out of range selections', () {
      for (final invalid in ['', '0', '7', '3-1', '1,,2', 'abc', '2-9']) {
        expect(() => PdfPageSelection.parse(invalid, 6),
            throwsFormatException, reason: 'Input: $invalid');
      }
      expect(() => PdfPageSelection.page('٤', 3), throwsFormatException);
    });
  });
}
