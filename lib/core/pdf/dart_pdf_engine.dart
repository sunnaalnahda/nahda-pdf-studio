import 'dart:typed_data';
import 'package:dart_pdf_editor/dart_pdf_editor.dart';
import 'package:flutter/material.dart';
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
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final fontBytes = fontData.buffer.asUint8List(
        fontData.offsetInBytes,
        fontData.lengthInBytes,
      );
      if (!controller.setCustomFont(fontBytes)) {
        throw const FormatException('تعذر تهيئة الخط العربي المدمج.');
      }
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
