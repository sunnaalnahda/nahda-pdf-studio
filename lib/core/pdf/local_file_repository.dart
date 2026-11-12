import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class SelectedPdf {
  const SelectedPdf(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class SelectedImage {
  const SelectedImage(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

abstract interface class PdfFileRepository {
  Future<SelectedPdf?> open();
  Future<SelectedImage?> openImage();
  Future<bool> saveImage(Uint8List bytes, String suggestedName);
  Future<bool> saveAs(Uint8List content, String name, {String? suggestedName});
}

/// Uses platform-native file/document pickers, not a cloud API or backend.
class LocalPdfFileRepository implements PdfFileRepository {
  const LocalPdfFileRepository();

  @override
  Future<SelectedPdf?> open() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (file == null) return null;
    final size = file.lengthSync() ?? await file.length();
    if (size != null && size > 80 * 1024 * 1024) {
      throw const FormatException(
        'الحد الحالي للملفات داخل الذاكرة 80 ميجابايت. سنوسع ذلك لاحقًا.',
      );
    }
    final bytes = await file.readAsBytes();
    return SelectedPdf(file.name, bytes);
  }

  @override
  Future<SelectedImage?> openImage() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (file == null) return null;
    final length = file.lengthSync() ?? await file.length();
    if (length != null && length > 20 * 1024 * 1024) {
      throw const FormatException('الصورة أكبر من الحد المسموح 20 MB.');
    }
    return SelectedImage(file.name, await file.readAsBytes());
  }

  @override
  Future<bool> saveImage(Uint8List bytes, String suggestedName) async {
    final result = await FilePicker.saveFile(
      dialogTitle: 'حفظ صورة PNG',
      fileName: suggestedName,
      bytes: bytes,
      mimeType: 'image/png',
    );
    return result != null;
  }

  @override
  Future<bool> saveAs(
    Uint8List content,
    String name, {
    String? suggestedName,
  }) async {
    final outputName = suggestedName ??
        (name.toLowerCase().endsWith('.pdf')
            ? '${name.substring(0, name.length - 4)}-edited.pdf'
            : '$name-edited.pdf');
    final result = await FilePicker.saveFile(
      dialogTitle: 'حفظ نسخة PDF معدّلة',
      fileName: outputName,
      bytes: content,
      mimeType: 'application/pdf',
    );
    return result != null;
  }
}
