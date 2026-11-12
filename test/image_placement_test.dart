import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/image_info.dart';
import 'package:nahda_pdf_studio/core/pdf/image_placement.dart';

final image = PdfImageInfo.inspect(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0k'
  'AAAAGUlEQVR4nGP4z8DwHwgbWBgZ/jNyicr7AgA3BAUOTnqjAAAAAABJRU5ErkJggg==',
));

void main() {
  test('centered image is aspect-correct and inside the original page', () {
    const placement = PdfImagePlacement(maxSidePoints: 200);
    final box = placement.calculate(image,
      pageLeft: 0, pageBottom: 0, pageWidth: 612, pageHeight: 792);
    expect(box.width, closeTo(200, 0.01));
    expect(box.height, closeTo(200, 0.01));
    expect(box.left, closeTo(206, 0.01));
    expect(box.bottom, closeTo(296, 0.01));
  });

  test('top-right anchored image respects crop-box offsets and margins', () {
    const placement = PdfImagePlacement(
      position: PdfImagePosition.topRight,
      maxSidePoints: 300,
      marginPoints: 24,
      opacity: 0.7,
    );
    final box = placement.calculate(image,
      pageLeft: 100, pageBottom: 200,
      pageWidth: 400, pageHeight: 500);
    expect(box.right, closeTo(476, 0.01));
    expect(box.top, closeTo(676, 0.01));
    expect(box.left >= 124, true);
  });

  test('a small page shrinks the picture instead of clipping it', () {
    const placement = PdfImagePlacement(maxSidePoints: 600);
    final box = placement.calculate(image,
      pageLeft: 0, pageBottom: 0, pageWidth: 100, pageHeight: 120);
    expect(box.width, closeTo(52, 0.01));
    expect(box.height, closeTo(52, 0.01));
    expect(box.left >= 24, true);
    expect(box.right <= 76, true);
  });

  test('rejects invalid size, opacity and empty page area', () {
    expect(() => const PdfImagePlacement(opacity: -0.1).calculate(image,
      pageLeft: 0, pageBottom: 0, pageWidth: 200, pageHeight: 300),
      throwsFormatException);
    expect(() => const PdfImagePlacement(maxSidePoints: 5).calculate(image,
      pageLeft: 0, pageBottom: 0, pageWidth: 200, pageHeight: 300),
      throwsFormatException);
    expect(() => const PdfImagePlacement().calculate(image,
      pageLeft: 0, pageBottom: 0, pageWidth: 30, pageHeight: 30),
      throwsFormatException);
  });
}
