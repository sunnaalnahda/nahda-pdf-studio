import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/image_info.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0k'
  'AAAAGUlEQVR4nGP4z8DwHwgbWBgZ/jNyicr7AgA3BAUOTnqjAAAAAABJRU5ErkJggg==',
);

void main() {
  test('PNG metadata is read without image decompression', () {
    final info = PdfImageInfo.inspect(_png);
    expect(info.format, PdfImageFormat.png);
    expect(info.width, 2);
    expect(info.height, 2);
    expect(info.aspectRatio, 1);
  });

  test('JPEG SOF marker supplies dimensions', () {
    final jpeg = Uint8List.fromList([
      0xff, 0xd8,
      0xff, 0xe0, 0x00, 0x04, 0x11, 0x22,
      0xff, 0xc0, 0x00, 0x11, 0x08, 0x00, 0x02, 0x00, 0x03,
      0x03, 0x01, 0x11, 0x00, 0x02, 0x11, 0x00, 0x03, 0x11, 0x00,
      0xff, 0xd9,
    ]);
    final info = PdfImageInfo.inspect(jpeg);
    expect(info.format, PdfImageFormat.jpeg);
    expect(info.width, 3);
    expect(info.height, 2);
  });

  test('rejects unsupported formats and malformed or oversized images', () {
    expect(() => PdfImageInfo.inspect(Uint8List(0)), throwsFormatException);
    expect(() => PdfImageInfo.inspect(Uint8List.fromList([1, 2, 3])),
        throwsFormatException);
    expect(() => PdfImageInfo.inspect(Uint8List(PdfImageInfo.maxBytes + 1)),
        throwsFormatException);

    final huge = Uint8List.fromList(_png);
    huge.setRange(16, 20, [0, 0, 0x27, 0x10]);
    huge.setRange(20, 24, [0, 0, 0x27, 0x10]);
    expect(() => PdfImageInfo.inspect(huge), throwsFormatException);

    expect(() => PdfImageInfo.inspect(Uint8List.fromList([
      0xff, 0xd8, 0xff, 0xe0, 0, 200, 1, 2,
    ])), throwsFormatException);
  });
}
