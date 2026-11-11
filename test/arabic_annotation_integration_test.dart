import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/dart_pdf_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Arabic annotation saves as an incremental PDF revision', (tester) async {
    final original = Uint8List.fromList(
      await File('tests/fixtures/vector_original.pdf').readAsBytes(),
    );
    final session = await const DartPdfEngine().open(
      filename: 'vector_original.pdf',
      data: original,
    );
    try {
      expect(session.pageCount, 2);
      expect(session.isModified, false);
      session.addArabicText(
        text: 'السلام عليكم ورحمة الله - تجربة ١٢٣',
        pageIndex: 0,
        fontSize: 18,
      );
      expect(session.isModified, true);
      expect(session.pageCount, 2);
      final saved = session.current;
      expect(saved.length, greaterThan(original.length));
      expect(saved.sublist(0, original.length), orderedEquals(original));
      session.markSaved();
      expect(session.isModified, false);
    } finally {
      session.dispose();
    }
  });
}
