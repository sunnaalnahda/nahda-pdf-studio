import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/dart_pdf_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Native PDF page operations preserve vector pages and remain undoable',
      () async {
    final bytes = Uint8List.fromList(
      await File('tests/fixtures/vector_original.pdf').readAsBytes(),
    );
    const engine = DartPdfEngine();
    final session = await engine.open(filename: 'original.pdf', data: bytes);
    try {
      expect(session.pageCount, 2);
      final initialRotation = session.controller.document.page(0).rotation;

      session.rotatePage(0, 90);
      expect(session.controller.document.page(0).rotation,
          (initialRotation + 90) % 360);

      session.duplicatePage(0);
      expect(session.pageCount, 3);

      session.movePage(0, 2);
      expect(session.pageCount, 3);

      session.addBlankPageAfter(0);
      expect(session.pageCount, 4);

      session.removePage(1);
      expect(session.pageCount, 3);
      expect(session.isModified, isTrue);

      final extracted = session.extractPages([0, 2]);
      final subset = await engine.open(filename: 'subset.pdf', data: extracted);
      try {
        expect(subset.pageCount, 2);
      } finally {
        subset.dispose();
      }

      session.appendPdf(bytes);
      expect(session.pageCount, 5);
      session.undo();
      expect(session.pageCount, 3);
      session.redo();
      expect(session.pageCount, 5);

      // Operations modify PDF structure, not by converting whole pages to images.
      expect(session.current.sublist(0, bytes.length), orderedEquals(bytes));
      session.markSaved();
      expect(session.isModified, isFalse);
      expect(() => session.removePage(99), throwsRangeError);
    } finally {
      session.dispose();
    }
  });

  test('Prevents deletion of the final PDF page', () async {
    final bytes = Uint8List.fromList(
      await File('tests/fixtures/vector_original.pdf').readAsBytes(),
    );
    final session = await const DartPdfEngine().open(
      filename: 'original.pdf', data: bytes,
    );
    try {
      session.removePage(1);
      expect(session.pageCount, 1);
      expect(() => session.removePage(0), throwsStateError);
      expect(session.pageCount, 1);
    } finally {
      session.dispose();
    }
  });
}
