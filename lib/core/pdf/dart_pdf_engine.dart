import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/services.dart';

import 'editing_engine.dart';

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
  void undo() => controller.undo();

  @override
  void redo() => controller.redo();

  @override
  void dispose() => controller.dispose();
}
