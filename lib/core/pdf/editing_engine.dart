import 'dart:typed_data';

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
  void undo();
  void redo();
  void dispose();
}
