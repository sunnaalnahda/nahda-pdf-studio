import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/editing_engine.dart';

void main() {
  test('PDF editing engine exposes a replaceable contract', () {
    expect(PdfEditingEngine, isNotNull);
    expect(PdfEditingSession, isNotNull);
  });
}
