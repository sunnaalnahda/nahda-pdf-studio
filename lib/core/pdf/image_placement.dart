import 'dart:math' as math;

import 'image_info.dart';

enum PdfImagePosition {
  center,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Page-space image bounds. PDF coordinates use a bottom-left origin.
class PdfImageBox {
  const PdfImageBox(this.left, this.bottom, this.right, this.top);

  final double left;
  final double bottom;
  final double right;
  final double top;

  double get width => right - left;
  double get height => top - bottom;
}

/// Image placement is separate from the PDF library and Flutter widgets.
/// Sizes are measured in PDF points (72 points = 1 inch).
class PdfImagePlacement {
  const PdfImagePlacement({
    this.position = PdfImagePosition.center,
    this.maxSidePoints = 220,
    this.marginPoints = 24,
    this.opacity = 1,
  });

  final PdfImagePosition position;
  final double maxSidePoints;
  final double marginPoints;
  final double opacity;

  PdfImageBox calculate(
    PdfImageInfo image, {
    required double pageLeft,
    required double pageBottom,
    required double pageWidth,
    required double pageHeight,
  }) {
    if (!pageWidth.isFinite || !pageHeight.isFinite ||
        pageWidth <= 0 || pageHeight <= 0 ||
        !maxSidePoints.isFinite || maxSidePoints < 24 ||
        maxSidePoints > 2000 ||
        !marginPoints.isFinite || marginPoints < 0 ||
        !opacity.isFinite || opacity < 0.05 || opacity > 1) {
      throw const FormatException('إعدادات موضع الصورة أو حجمها غير صحيحة.');
    }

    final usableWidth = pageWidth - marginPoints * 2;
    final usableHeight = pageHeight - marginPoints * 2;
    if (usableWidth <= 1 || usableHeight <= 1) {
      throw const FormatException('المساحة المتاحة للصورة صغيرة جدًا.');
    }

    final width = image.width.toDouble();
    final height = image.height.toDouble();
    final factor = math.min(
      maxSidePoints / math.max(width, height),
      math.min(usableWidth / width, usableHeight / height),
    );
    final w = width * factor;
    final h = height * factor;
    final x = switch (position) {
      PdfImagePosition.center => pageLeft + (pageWidth - w) / 2,
      PdfImagePosition.topLeft || PdfImagePosition.bottomLeft =>
        pageLeft + marginPoints,
      PdfImagePosition.topRight || PdfImagePosition.bottomRight =>
        pageLeft + pageWidth - marginPoints - w,
    };
    final y = switch (position) {
      PdfImagePosition.center => pageBottom + (pageHeight - h) / 2,
      PdfImagePosition.topLeft || PdfImagePosition.topRight =>
        pageBottom + pageHeight - marginPoints - h,
      PdfImagePosition.bottomLeft || PdfImagePosition.bottomRight =>
        pageBottom + marginPoints,
    };
    return PdfImageBox(x, y, x + w, y + h);
  }
}
