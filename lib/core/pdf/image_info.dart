import 'dart:typed_data';

enum PdfImageFormat { png, jpeg }

/// Inspects image headers without decompressing untrusted image data.
/// The PDF engine performs the final actual PNG/JPEG decode.
class PdfImageInfo {
  const PdfImageInfo({
    required this.format,
    required this.width,
    required this.height,
    required this.length,
  });

  static const maxBytes = 20 * 1024 * 1024;
  static const maxPixels = 32 * 1024 * 1024;

  final PdfImageFormat format;
  final int width;
  final int height;
  final int length;

  double get aspectRatio => width / height;

  static PdfImageInfo inspect(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('حجم الصورة غير مدعوم (الحد 20 MB).');
    }
    if (_isPng(bytes)) {
      if (bytes.length < 33 ||
          bytes[12] != 0x49 || bytes[13] != 0x48 ||
          bytes[14] != 0x44 || bytes[15] != 0x52) {
        throw const FormatException('ترويسة PNG غير مكتملة.');
      }
      return _validated(
        PdfImageFormat.png,
        _u32(bytes, 16),
        _u32(bytes, 20),
        bytes.length,
      );
    }
    if (bytes.length >= 4 && bytes[0] == 0xff && bytes[1] == 0xd8) {
      return _jpeg(bytes);
    }
    throw const FormatException('الصور المدعومة حاليًا PNG وJPEG فقط.');
  }

  static bool _isPng(Uint8List data) {
    const header = [137, 80, 78, 71, 13, 10, 26, 10];
    if (data.length < header.length) return false;
    for (var i = 0; i < header.length; i++) {
      if (data[i] != header[i]) return false;
    }
    return true;
  }

  static int _u16(Uint8List d, int offset) =>
      (d[offset] << 8) | d[offset + 1];

  static int _u32(Uint8List d, int offset) =>
      (d[offset] << 24) |
      (d[offset + 1] << 16) |
      (d[offset + 2] << 8) |
      d[offset + 3];

  static PdfImageInfo _validated(
    PdfImageFormat format, int width, int height, int length,
  ) {
    if (width <= 0 || height <= 0 ||
        width > 32768 || height > 32768 ||
        width * height > maxPixels) {
      throw const FormatException(
        'أبعاد الصورة كبيرة جدًا (الحد 32 ميجابكسل).',
      );
    }
    return PdfImageInfo(
      format: format,
      width: width,
      height: height,
      length: length,
    );
  }

  static PdfImageInfo _jpeg(Uint8List data) {
    var position = 2;
    const frames = {
      0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7,
      0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf,
    };

    while (position < data.length - 1) {
      // Before SOS, JPEG consists of length-delimited marker segments.
      while (position < data.length && data[position] != 0xff) {
        position++;
      }
      if (position >= data.length) break;
      while (position < data.length && data[position] == 0xff) {
        position++;
      }
      if (position >= data.length) break;
      final marker = data[position++];
      if (marker == 0xda || marker == 0xd9) break;
      if (marker == 0x00 ||
          marker == 0xd8 || marker == 0x01 ||
          (marker >= 0xd0 && marker <= 0xd7)) {
        continue;
      }
      if (position + 2 > data.length) break;
      final size = _u16(data, position);
      if (size < 2 || position + size > data.length) {
        throw const FormatException('مقطع JPEG غير صالح.');
      }
      if (frames.contains(marker)) {
        if (size < 7) {
          throw const FormatException('بيانات أبعاد JPEG غير صالحة.');
        }
        final height = _u16(data, position + 3);
        final width = _u16(data, position + 5);
        return _validated(
          PdfImageFormat.jpeg, width, height, data.length,
        );
      }
      position += size;
    }
    throw const FormatException('تعذر قراءة أبعاد JPEG.');
  }
}
