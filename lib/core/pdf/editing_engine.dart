import 'dart:typed_data';

import 'image_placement.dart';

/// Port used by the workspace. The concrete adapter can be replaced without
/// changing the workspace's document lifecycle or file storage.
abstract interface class PdfEditingEngine {
  Future<PdfEditingSession> open({
    required String filename,
    required Uint8List data,
  });
}

abstract interface class PdfEditingSession {
  String get filename;
  Uint8List get original;
  Uint8List get current;
  int get pageCount;
  bool get isModified;
  void markSaved();
  bool get canUndo;
  bool get canRedo;
  void addArabicText({
    required String text,
    required int pageIndex,
    double fontSize,
  });
  /// Page operations use zero-based indices and preserve editable PDF data.
  void rotatePage(int index, int degrees);
  void duplicatePage(int index);
  void movePage(int from, int to);
  void removePage(int index);
  void addBlankPageAfter(int index);
  void appendPdf(Uint8List bytes);
  Uint8List extractPages(List<int> indices);
  /// Insert PNG/JPEG while retaining the PDF page's original vector content.
  Future<void> insertImage(
    Uint8List bytes, {
    required int pageIndex,
    required PdfImagePlacement placement,
  });
  bool get hasSelectedImage;
  bool get canCropSelectedImage;
  bool cropSelectedImage({
    required double left,
    required double right,
    required double top,
    required double bottom,
  });
  bool resetSelectedImageCrop();
  bool rotateSelectedImage(double degrees);
  bool resizeSelectedImage(double maxSidePoints);
  bool moveSelectedImage(double dx, double dy);
  bool removeSelectedImage();
  bool get canReplaceSelectedContentImage;
  Future<bool> replaceSelectedContentImage(Uint8List bytes);
  void undo();
  void redo();
  void dispose();
}
