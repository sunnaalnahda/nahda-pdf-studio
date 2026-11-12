import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/dart_pdf_engine.dart';
import 'package:nahda_pdf_studio/features/workspace/document_workspace.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Independent native PDF sessions retain separate edits and undo histories',
      () async {
    final source = await File('tests/fixtures/vector_original.pdf')
        .readAsBytes();
    const engine = DartPdfEngine();
    final tabs = DocumentWorkspace<DartPdfSession>();

    final first = tabs.add(await engine.open(
      filename: 'first.pdf',
      data: source,
    ));
    final second = tabs.add(await engine.open(
      filename: 'second.pdf',
      data: source,
    ));
    try {
      expect(tabs.count, 2);
      expect(tabs.active, same(second));
      expect(first.session.pageCount, 2);
      expect(second.session.pageCount, 2);

      tabs.activate(first);
      first.session.addBlankPageAfter(0);
      first.previewMode = true;
      expect(first.session.pageCount, 3);
      expect(first.session.isModified, isTrue);

      tabs.activate(second);
      expect(second.session.pageCount, 2);
      expect(second.previewMode, isFalse);
      expect(second.session.isModified, isFalse);

      second.session.duplicatePage(1);
      expect(second.session.pageCount, 3);
      second.session.undo();
      expect(second.session.pageCount, 2);

      tabs.activate(first);
      expect(first.session.pageCount, 3);
      expect(first.previewMode, isTrue);
      first.session.undo();
      expect(first.session.pageCount, 2);

      tabs.close(second);
      expect(tabs.active, same(first));
      expect(tabs.count, 1);
    } finally {
      tabs.dispose();
    }
  });
}
