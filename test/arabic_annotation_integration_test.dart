import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:nahda_pdf_studio/core/pdf/dart_pdf_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // This is an asynchronous I/O + font-loading test, not a widget test.
  // testWidgets uses FakeAsync; awaiting rootBundle.load here can deadlock.
  test('Arabic annotation saves as an incremental PDF revision', () async {
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
      const arabic = 'السَّلَامُ عليكم ورحمة الله - تجربة ١٢٣ ABC 456';
      session.addArabicText(
        text: arabic,
        pageIndex: 0,
        fontSize: 18,
      );
      // The stored annotation must keep Unicode logical order, not a visually
      // reversed string. Saving the bytes alone did not catch the original bug.
      expect(session.controller.activeFont, isNull);
      expect(session.controller.document.page(0).annotations.last.contents, arabic);
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
  test('Arabic insertion resets an unsafe selected embedded font', () async {
    final original = Uint8List.fromList(
      await File('tests/fixtures/vector_original.pdf').readAsBytes(),
    );
    final session = await const DartPdfEngine().open(
      filename: 'vector_original.pdf',
      data: original,
    );
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final font = fontData.buffer.asUint8List(fontData.offsetInBytes, fontData.lengthInBytes);
      expect(session.controller.setCustomFont(font), isTrue);
      expect(session.controller.activeFont, isNotNull);

      const input = 'شركة صُنّاع النهضة ١٢٣ ABC';
      session.addArabicText(text: input, pageIndex: 0);
      expect(session.controller.activeFont, isNull);
      expect(session.controller.document.page(0).annotations.last.contents, input);
      final reopened = await const DartPdfEngine().open(filename: 'saved.pdf', data: session.current);
      try {
        expect(reopened.controller.document.page(0).annotations.last.contents, input);
        expect(reopened.pageCount, 2);
      } finally {
        reopened.dispose();
      }
    } finally {
      session.dispose();
    }
  });

}
