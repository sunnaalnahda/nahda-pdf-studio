import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/services.dart';

import 'editing_engine.dart';
import 'image_info.dart';
import 'image_placement.dart';

/// Pure local PDF editor. FreeText annotations have vector appearance streams.
/// Their creation appends PDF revisions rather than rasterizing whole pages.
class DartPdfEngine implements PdfEditingEngine {
  const DartPdfEngine();

  @override
  Future<DartPdfSession> open({
    required String filename,
    required Uint8List data,
  }) async {
    // Read before creating a PDF session: refuse arbitrary file uploads.
    final head = String.fromCharCodes(data.take(1024));
    if (!head.contains('%PDF-')) {
      throw const FormatException('هذا الملف لا يحتوي على ترويسة PDF صحيحة.');
    }
    final controller = PdfEditingController(data);
    try {
      // Preferences are restored asynchronously from the user's previous
      // sessions. Wait before clearing a previously persisted embedded Amiri:
      // otherwise that old choice can return right after document open.
      await controller.preferences.ready;
      controller.activeFont = null;
      // Do not globally select the embedded Amiri font for newly-authored text.
      // dart_pdf_editor 15.0.0 reorders PdfEmbeddedFont RTL glyphs into a
      // visual stream and can produce reversed Arabic in the editor. Its
      // Unicode-font fallback retains logical Unicode for the text engine.
      // Embedded, fully shaped Arabic is NOT solved yet; see docs/QA_AND_LIMITATIONS.md.
      return DartPdfSession(
        filename: filename,
        original: Uint8List.fromList(data),
        controller: controller,
      );
    } catch (_) {
      controller.dispose();
      rethrow;
    }
  }
}

class DartPdfSession implements PdfEditingSession {
  DartPdfSession({
    required this.filename,
    required this.original,
    required this.controller,
  }) : _lastSavedRevision = controller.revisionId;

  @override
  final String filename;

  @override
  final Uint8List original;

  int _lastSavedRevision;

  // Only the Flutter adapter layer accesses this vendor-specific controller.
  final PdfEditingController controller;

  @override
  Uint8List get current => controller.bytes;

  @override
  int get pageCount => controller.document.pageCount;

  @override
  bool get isModified => controller.revisionId != _lastSavedRevision;

  @override
  void markSaved() => _lastSavedRevision = controller.revisionId;

  @override
  bool get canUndo => controller.canUndo;

  @override
  bool get canRedo => controller.canRedo;

  @override
  void addArabicText({
    required String text,
    required int pageIndex,
    double fontSize = 20,
  }) {
    if (text.trim().isEmpty) {
      throw const FormatException('الرجاء إدخال النص أولاً.');
    }
    if (pageIndex < 0 || pageIndex >= pageCount) {
      throw RangeError.range(pageIndex + 1, 1, pageCount, 'رقم الصفحة');
    }
    // The editor's embedded-font path currently reverses/does not shape Arabic
    // reliably. Route our Arabic button through its logical-Unicode fallback.
    // This avoids silent reversed glyph order but DOES NOT embed Amiri.
    // Keep the user's actual string untouched, including diacritics and numbers.
    controller.activeFont = null;
    controller.preferences.fontSize = fontSize.clamp(8.0, 72.0).toDouble();
    controller.color = const Color(0xFF11243A);
    // placeFreeText clamps the box to the crop box for unusual page sizes.
    // Its saved PDF annotation has its own editable vector appearance stream.
    final inserted = controller.placeFreeText(
      pageIndex,
      280,
      710,
      text,
      width: 350,
    );
    if (!inserted) {
      throw const FormatException('لم يتم إدراج النص في الصفحة.');
    }
  }

  @override
  Future<void> insertImage(
    Uint8List bytes, {
    required int pageIndex,
    required PdfImagePlacement placement,
  }) async {
    _checkPage(pageIndex);
    final image = PdfImageInfo.inspect(bytes);
    final page = controller.document.page(pageIndex);
    final crop = page.cropBox;
    final box = placement.calculate(
      image,
      pageLeft: crop.left,
      pageBottom: crop.bottom,
      pageWidth: crop.width,
      pageHeight: crop.height,
    );

    // The editor embeds a PNG/JPEG as a /Stamp image XObject. Every original
    // text and vector stream stays intact. Alpha is set on the same edit.
    final previousOpacity = controller.preferences.opacity;
    try {
      controller.preferences.opacity = placement.opacity;
      final added = await controller.addImageInRectAsync(
        pageIndex,
        PdfRect(box.left, box.bottom, box.right, box.top),
        bytes,
      );
      if (!added) {
        throw const FormatException(
          'تعذر تضمين الصورة. جرب PNG أو JPEG غير تالف.',
        );
      }
    } finally {
      controller.preferences.opacity = previousOpacity;
    }
  }

  bool get _isImageStamp =>
      controller.selectedAnnotation?.isImageStamp == true;

  @override
  bool get hasSelectedImage => _isImageStamp;

  @override
  bool get canCropSelectedImage =>
      _isImageStamp && controller.canCropSelected;

  @override
  bool cropSelectedImage({
    required double left,
    required double right,
    required double top,
    required double bottom,
  }) {
    if (!canCropSelectedImage) return false;
    for (final value in [left, right, top, bottom]) {
      if (!value.isFinite || value < 0 || value > 0.9) {
        throw const FormatException('نسبة القص يجب أن تكون بين 0 و90%.');
      }
    }
    if (left + right >= 0.95 || top + bottom >= 0.95) {
      throw const FormatException('القص سيزيل الصورة بالكامل.');
    }
    final rectangle = controller.selectedAnnotation!.rect;
    controller.cropSelectedImage(PdfRect(
      rectangle.left + left * rectangle.width,
      rectangle.bottom + bottom * rectangle.height,
      rectangle.right - right * rectangle.width,
      rectangle.top - top * rectangle.height,
    ));
    return true;
  }

  @override
  bool resetSelectedImageCrop() {
    if (!canCropSelectedImage || !controller.selectedHasCrop) return false;
    controller.resetSelectedImageCrop();
    return true;
  }

  @override
  bool rotateSelectedImage(double degrees) {
    if (!_isImageStamp || !controller.canRotateSelected ||
        !degrees.isFinite || degrees == 0) {
      return false;
    }
    controller.rotateSelected(degrees);
    return true;
  }

  @override
  bool resizeSelectedImage(double maxSidePoints) {
    if (!_isImageStamp || !controller.canResizeSelected ||
        !maxSidePoints.isFinite || maxSidePoints < 12 ||
        maxSidePoints > 2000) {
      return false;
    }
    final rect = controller.selectedAnnotation!.rect;
    if (rect.width <= 0 || rect.height <= 0) return false;
    final scale = maxSidePoints /
        (rect.width > rect.height ? rect.width : rect.height);
    final width = rect.width * scale;
    final height = rect.height * scale;
    final cx = (rect.left + rect.right) / 2;
    final cy = (rect.top + rect.bottom) / 2;
    controller.resizeSelected(PdfRect(
      cx - width / 2, cy - height / 2,
      cx + width / 2, cy + height / 2,
    ));
    return true;
  }

  @override
  bool moveSelectedImage(double dx, double dy) {
    if (!_isImageStamp || !dx.isFinite || !dy.isFinite) return false;
    controller.moveSelected(dx, dy);
    return true;
  }

  @override
  bool removeSelectedImage() {
    if (!_isImageStamp) return false;
    final slot = controller.selectedAnnotationSlot;
    if (slot == null) return false;
    controller.deleteAnnotation(slot.$1, slot.$2);
    return true;
  }

  @override
  double get selectedImageOpacity =>
      _isImageStamp ? (controller.selectedAnnotationStyle?.opacity ?? 1) : 1;

  @override
  bool setSelectedImageOpacity(double opacity) {
    if (!_isImageStamp || !opacity.isFinite ||
        opacity < 0.05 || opacity > 1) {
      return false;
    }
    return controller.restyleSelected(opacity: opacity);
  }

  @override
  bool get canReplaceSelectedContentImage =>
      controller.canReplaceSelectedElementImage;

  @override
  Future<bool> replaceSelectedContentImage(Uint8List bytes) async {
    PdfImageInfo.inspect(bytes);
    if (!controller.canReplaceSelectedElementImage) return false;
    // Replaces only the selected original page-content image, not the PDF
    // document or its vector siblings. It becomes an editable image stamp.
    return controller.replaceSelectedElementImageAsync(bytes);
  }

  void _checkPage(int index) {
    RangeError.checkValidIndex(index, null, 'page', pageCount);
  }

  @override
  void rotatePage(int index, int degrees) {
    _checkPage(index);
    if (degrees != 90 && degrees != -90 && degrees != 180) {
      throw ArgumentError.value(degrees, 'degrees');
    }
    if (!controller.rotatePages([index], degrees)) {
      throw StateError('لم يتم تدوير الصفحة.');
    }
  }

  @override
  void duplicatePage(int index) {
    _checkPage(index);
    if (!controller.duplicatePages([index])) {
      throw StateError('تعذر تكرار الصفحة.');
    }
  }

  @override
  void movePage(int from, int to) {
    _checkPage(from);
    _checkPage(to);
    controller.movePage(from, to);
  }

  @override
  void removePage(int index) {
    _checkPage(index);
    if (pageCount <= 1) {
      throw StateError('لا يمكن حذف آخر صفحة من المستند.');
    }
    controller.removePage(index);
  }

  @override
  void addBlankPageAfter(int index) {
    _checkPage(index);
    controller.addBlankPage(at: index + 1);
  }

  @override
  void appendPdf(Uint8List bytes) {
    if (bytes.length < 5 ||
        !String.fromCharCodes(bytes.take(1024)).contains('%PDF-')) {
      throw const FormatException('الملف الثاني ليس مستند PDF صالحًا.');
    }
    controller.insertPagesFromBytes(bytes);
  }

  @override
  Uint8List extractPages(List<int> indices) {
    if (indices.isEmpty) {
      throw const FormatException('اختر صفحة واحدة على الأقل.');
    }
    for (final index in indices) {
      _checkPage(index);
    }
    return controller.exportPages(indices);
  }

  @override
  void undo() => controller.undo();

  @override
  void redo() => controller.redo();

  @override
  void dispose() => controller.dispose();
}
