import '../../core/pdf/editing_engine.dart';

/// A single open PDF and its private presentation state.
class OpenDocument<T extends PdfEditingSession> {
  OpenDocument({
    required this.id,
    required this.session,
  });

  final int id;
  final T session;
  bool previewMode = false;
}

/// In-memory tab lifecycle. Does not persist private PDFs to disk or a cloud.
///
/// Each tab owns its session and undo history independently. The caller must
/// confirm unsaved changes before closing a tab; [close] deliberately performs
/// no confirmation or file writes.
class DocumentWorkspace<T extends PdfEditingSession> {
  DocumentWorkspace({
    this.maxTabs = 6,
    this.maxOriginalBytes = 160 * 1024 * 1024,
  })  : assert(maxTabs > 0),
        assert(maxOriginalBytes > 0);

  final int maxTabs;
  final int maxOriginalBytes;

  final List<OpenDocument<T>> _documents = [];
  OpenDocument<T>? _active;
  int _nextId = 1;

  List<OpenDocument<T>> get documents => List.unmodifiable(_documents);
  OpenDocument<T>? get active => _active;
  int get count => _documents.length;
  int get totalOriginalBytes => _documents.fold<int>(
        0, (sum, document) => sum + document.session.original.length,
      );

  bool canOpen(int bytes) =>
      bytes >= 0 &&
      count < maxTabs &&
      totalOriginalBytes + bytes <= maxOriginalBytes;

  OpenDocument<T> add(T session) {
    if (!canOpen(session.original.length)) {
      throw StateError('Too many open documents or memory budget exceeded.');
    }
    final document = OpenDocument<T>(id: _nextId++, session: session);
    _documents.add(document);
    _active = document;
    return document;
  }

  bool contains(OpenDocument<T> document) =>
      _documents.any((item) => identical(item, document));

  void activate(OpenDocument<T> document) {
    if (!contains(document)) {
      throw ArgumentError.value(document, 'document', 'Not an open tab');
    }
    _active = document;
  }

  void cycle({bool backwards = false}) {
    if (_documents.length < 2) return;
    final index = _documents.indexOf(_active!);
    final offset = backwards ? -1 : 1;
    final next = (index + offset + _documents.length) % _documents.length;
    _active = _documents[next];
  }

  /// Releases one tab's PDF engine and selects a surviving tab.
  bool close(
    OpenDocument<T> document, {
    bool disposeSession = true,
  }) {
    final index = _documents.indexWhere((item) => identical(item, document));
    if (index < 0) return false;
    final wasActive = identical(_active, document);
    _documents.removeAt(index);
    if (wasActive) {
      if (_documents.isEmpty) {
        _active = null;
      } else {
        final newIndex = index >= _documents.length
            ? _documents.length - 1
            : index;
        _active = _documents[newIndex];
      }
    }
    if (disposeSession) document.session.dispose();
    return true;
  }

  void dispose() {
    for (final document in _documents) {
      document.session.dispose();
    }
    _documents.clear();
    _active = null;
  }
}
