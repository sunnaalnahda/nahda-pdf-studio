import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/editing_engine.dart';
import 'package:nahda_pdf_studio/features/workspace/document_workspace.dart';

class FakeSession implements PdfEditingSession {
  FakeSession(this.filename, {int bytes = 1})
      : original = Uint8List(bytes);

  @override
  final String filename;
  @override
  final Uint8List original;
  int disposeCalls = 0;
  bool modified = false;
  @override
  Uint8List get current => original;
  @override
  int get pageCount => 1;
  @override
  bool get isModified => modified;
  @override
  void markSaved() => modified = false;
  @override
  bool get canUndo => false;
  @override
  bool get canRedo => false;
  @override
  void addArabicText({required String text, required int pageIndex,
      double fontSize = 20}) {}
  @override
  void rotatePage(int index, int degrees) {}
  @override
  void duplicatePage(int index) {}
  @override
  void movePage(int from, int to) {}
  @override
  void removePage(int index) {}
  @override
  void addBlankPageAfter(int index) {}
  @override
  void appendPdf(Uint8List bytes) {}
  @override
  Uint8List extractPages(List<int> indices) => original;
  @override
  void undo() {}
  @override
  void redo() {}
  @override
  void dispose() => disposeCalls++;
}

void main() {
  group('Independent PDF tabs', () {
    test('opening switches active tab without disposing previous PDFs', () {
      final workspace = DocumentWorkspace<FakeSession>();
      final a = FakeSession('a.pdf');
      final b = FakeSession('b.pdf');
      final first = workspace.add(a);
      final second = workspace.add(b);

      expect(workspace.count, 2);
      expect(workspace.active, same(second));
      expect(first.session.filename, 'a.pdf');
      expect(a.disposeCalls, 0);
      workspace.activate(first);
      expect(workspace.active, same(first));
      first.previewMode = true;
      expect(second.previewMode, false);

      workspace.dispose();
      expect(a.disposeCalls, 1);
      expect(b.disposeCalls, 1);
    });

    test('cycling wraps and preserves independent unsaved state', () {
      final workspace = DocumentWorkspace<FakeSession>();
      final a = FakeSession('a.pdf')..modified = true;
      final first = workspace.add(a);
      final middle = workspace.add(FakeSession('b.pdf'));
      final last = workspace.add(FakeSession('c.pdf'));

      workspace.cycle();
      expect(workspace.active, same(first));
      workspace.cycle(backwards: true);
      expect(workspace.active, same(last));
      workspace.activate(middle);
      expect(a.isModified, true);
      expect(workspace.active!.session.isModified, false);
      workspace.dispose();
    });

    test('closing the active or inactive tab selects a valid neighbor', () {
      final workspace = DocumentWorkspace<FakeSession>();
      final a = FakeSession('a.pdf');
      final b = FakeSession('b.pdf');
      final c = FakeSession('c.pdf');
      final first = workspace.add(a);
      final middle = workspace.add(b);
      final last = workspace.add(c);
      expect(workspace.close(middle), true);
      expect(workspace.active, same(last));
      expect(b.disposeCalls, 1);
      expect(workspace.close(middle), false);
      expect(b.disposeCalls, 1);
      expect(workspace.close(last), true);
      expect(workspace.active, same(first));
      expect(workspace.close(first), true);
      expect(workspace.active, isNull);
      expect(workspace.count, 0);
      expect(a.disposeCalls, 1);
      expect(c.disposeCalls, 1);
    });

    test('caller can defer PDF disposal until after the final UI frame', () {
      final workspace = DocumentWorkspace<FakeSession>();
      final session = FakeSession('pending-dispose.pdf');
      final tab = workspace.add(session);
      expect(workspace.close(tab, disposeSession: false), true);
      expect(session.disposeCalls, 0);
      expect(workspace.count, 0);
      session.dispose();
      expect(session.disposeCalls, 1);
    });

    test('capacity and aggregate input size protect memory usage', () {
      final workspace = DocumentWorkspace<FakeSession>(
        maxTabs: 2, maxOriginalBytes: 5,
      );
      workspace.add(FakeSession('first', bytes: 3));
      expect(workspace.canOpen(3), false);
      final second = workspace.add(FakeSession('second', bytes: 2));
      expect(workspace.canOpen(0), false);
      expect(() => workspace.add(FakeSession('third')), throwsStateError);
      expect(workspace.totalOriginalBytes, 5);
      workspace.close(second);
      expect(workspace.canOpen(2), true);
      workspace.dispose();
    });
  });
}
