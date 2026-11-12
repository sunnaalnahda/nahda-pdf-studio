import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/dart_pdf_engine.dart';
import 'package:nahda_pdf_studio/core/pdf/image_placement.dart';

final png = Uint8List.fromList(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0k'
  'AAAAGUlEQVR4nGP4z8DwHwgbWBgZ/jNyicr7AgA3BAUOTnqjAAAAAABJRU5ErkJggg==',
));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Image stamp insertion preserves original vectors and survives reopen',
      () async {
    final original = Uint8List.fromList(
        await File('tests/fixtures/vector_original.pdf').readAsBytes());
    const engine = DartPdfEngine();
    final session = await engine.open(filename: 'vector.pdf', data: original);
    try {
      await session.insertImage(
        png,
        pageIndex: 0,
        placement: const PdfImagePlacement(
          position: PdfImagePosition.center,
          maxSidePoints: 120,
          opacity: 0.75,
        ),
      );
      expect(session.pageCount, 2);
      expect(session.isModified, isTrue);
      final stamp = session.controller.document.page(0).annotations.last;
      expect(stamp.subtype, 'Stamp');
      expect(stamp.isImageStamp, isTrue);
      expect(stamp.rect.width, closeTo(120, 1));
      expect(session.hasSelectedImage, isTrue);

      expect(session.moveSelectedImage(10, 0), isTrue);
      expect(session.resizeSelectedImage(160), isTrue);
      expect(session.canCropSelectedImage, isTrue);
      expect(session.cropSelectedImage(
        left: .1, right: .1, top: .1, bottom: .1,
      ), isTrue);
      expect(session.resetSelectedImageCrop(), isTrue);
      expect(session.setSelectedImageOpacity(.5), isTrue);
      expect(session.rotateSelectedImage(90), isTrue);

      final saved = session.current;
      expect(saved.length, greaterThan(original.length));
      expect(saved.sublist(0, original.length), orderedEquals(original));
      final reopened = await engine.open(filename: 'saved.pdf', data: saved);
      try {
        expect(reopened.pageCount, 2);
        expect(reopened.controller.document.page(0).annotations.last.isImageStamp,
          isTrue);
      } finally {
        reopened.dispose();
      }
      session.undo();
      expect(session.canRedo, isTrue);
      session.redo();
      expect(session.isModified, isTrue);
    } finally {
      session.dispose();
    }
  });

  test('Invalid or excessive PNG rejected before PDF revision', () async {
    final bytes = Uint8List.fromList(
      await File('tests/fixtures/vector_original.pdf').readAsBytes(),
    );
    final session = await const DartPdfEngine().open(
      filename: 'vector.pdf', data: bytes,
    );
    try {
      await expectLater(
        session.insertImage(Uint8List.fromList([1, 2, 3]),
          pageIndex: 0, placement: const PdfImagePlacement()),
        throwsFormatException,
      );
      expect(session.isModified, isFalse);
      expect(session.pageCount, 2);
    } finally {
      session.dispose();
    }
  });
}
