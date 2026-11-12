import 'dart:async';
import 'dart:typed_data';
import 'package:dart_pdf_editor/dart_pdf_editor.dart' as editor;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:pdfrx/pdfrx.dart' as pdf_viewer;

import '../../app/theme.dart';
import '../../core/pdf/dart_pdf_engine.dart';
import '../../core/pdf/local_file_repository.dart';
import 'page_tools_dialog.dart';
import 'document_workspace.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    required this.arabic,
    required this.onSwitchLanguage,
  });

  final bool arabic;
  final VoidCallback onSwitchLanguage;

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  final _engine = const DartPdfEngine();
  final _files = const LocalPdfFileRepository();
  final _documents = DocumentWorkspace<DartPdfSession>();
  bool _busy = false;

  DartPdfSession? get _session => _documents.active?.session;
  bool get _previewMode => _documents.active?.previewMode ?? false;
  set _previewMode(bool value) {
    final tab = _documents.active;
    if (tab != null) tab.previewMode = value;
  }

  String t(String ar, String en) => widget.arabic ? ar : en;

  @override
  void dispose() {
    for (final document in _documents.documents) {
      document.session.controller.removeListener(_documentChanged);
    }
    _documents.dispose();
    super.dispose();
  }

  void _documentChanged() {
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _containsSession(DartPdfSession session) =>
      _documents.documents.any((tab) => identical(tab.session, session));

  Future<void> _open() async {
    if (_busy) return;
    if (!_documents.canOpen(0)) {
      _toast(t(
        'الحد الأقصى ${_documents.maxTabs} مستندات مفتوحة. أغلق تبويبًا قبل إضافة ملف.',
        'Maximum ${_documents.maxTabs} open documents. Close a tab first.',
      ));
      return;
    }
    setState(() => _busy = true);
    try {
      final selected = await _files.open();
      if (selected == null || !mounted) return;
      if (!_documents.canOpen(selected.bytes.length)) {
        throw FormatException(t(
          'الحد الأقصى لمجموع الملفات المفتوحة 160 ميجابايت. احفظ وأغلق بعض الملفات أولًا.',
          'Open PDFs exceed the 160 MB combined memory budget. Close unused tabs.',
        ));
      }
      final opened = await _engine.open(
        filename: selected.name,
        data: selected.bytes,
      );
      if (!mounted) {
        opened.dispose();
        return;
      }
      try {
        _documents.add(opened);
        opened.controller.addListener(_documentChanged);
      } catch (_) {
        opened.dispose();
        rethrow;
      }
      setState(() {});
    } catch (error) {
      _toast(t('فشل فتح الملف: $error', 'Unable to open PDF: $error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Save a specific session, never a tab that might become active later.
  /// Returns false when Save As is canceled or fails.
  Future<bool> _saveSession(
    DartPdfSession session, [
    Uint8List? editedBytes,
  ]) async {
    if (_busy || !_containsSession(session)) return false;
    setState(() => _busy = true);
    try {
      final savedRevision = session.controller.revisionId;
      final bytes = Uint8List.fromList(editedBytes ?? session.current);
      final saved = await _files.saveAs(bytes, session.filename);
      if (saved) {
        // Do not mark later edits as saved if the document changed during I/O.
        if (savedRevision == session.controller.revisionId) {
          session.markSaved();
        }
        if (mounted) setState(() {});
        _toast(t('تم حفظ نسخة جديدة من المستند.', 'A new PDF copy was saved.'));
      }
      return saved;
    } catch (error) {
      _toast(t('تعذر حفظ الملف: $error', 'Unable to save PDF: $error'));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final session = _session;
    if (session != null) await _saveSession(session);
  }

  Future<void> _closeTab(OpenDocument<DartPdfSession> tab) async {
    if (_busy || !_documents.contains(tab)) return;
    if (tab.session.isModified) {
      final choice = await showDialog<_CloseChoice>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('تعديلات لم تُحفظ', 'Unsaved PDF edits')),
          content: Text(t(
            'يوجد تعديل غير محفوظ في ${tab.session.filename}. هل تريد حفظ نسخة قبل إغلاقه؟',
            'There are unsaved edits in ${tab.session.filename}. Save a copy before closing?',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('إلغاء', 'Cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _CloseChoice.discard),
              child: Text(t('إغلاق دون حفظ', 'Discard edits')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, _CloseChoice.save),
              child: Text(t('حفظ نسخة وإغلاق', 'Save copy and close')),
            ),
          ],
        ),
      );
      if (!mounted || !_documents.contains(tab) || choice == null) return;
      if (choice == _CloseChoice.save) {
        final saved = await _saveSession(tab.session);
        if (!saved || !mounted || !_documents.contains(tab)) return;
        // A new revision during asynchronous saving must not be discarded.
        if (tab.session.isModified) return;
      }
    }
    tab.session.controller.removeListener(_documentChanged);
    setState(() {
      _documents.close(tab, disposeSession: false);
    });
    // The editor widget must detach from the old controller before disposal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tab.session.dispose();
    });
  }

  void _cycleTabs({bool backwards = false}) {
    if (_busy || _documents.count < 2) return;
    setState(() => _documents.cycle(backwards: backwards));
  }

  Future<void> _saveAllModified() async {
    if (_busy) return;
    final modified = _documents.documents
        .where((tab) => tab.session.isModified).toList();
    if (modified.isEmpty) {
      _toast(t('لا توجد تعديلات للحفظ.', 'There are no unsaved edits.'));
      return;
    }
    var savedCount = 0;
    for (final tab in modified) {
      if (!mounted || !_documents.contains(tab)) return;
      final saved = await _saveSession(tab.session);
      if (!saved || !mounted) {
        _toast(t('توقف الحفظ. المستندات المتبقية لم تُحفظ.',
          'Saving stopped. Remaining documents were not saved.'));
        return;
      }
      savedCount++;
    }
    _toast(t('تم حفظ نسخ من $savedCount مستندات.',
      'Saved copies of $savedCount documents.'));
  }

  Future<void> _showShortcuts() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t('اختصارات لوحة المفاتيح', 'Keyboard shortcuts')),
      content: SizedBox(
        width: 390,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('Ctrl+O — فتح مستند PDF', 'Ctrl+O — Open PDF')),
            const SizedBox(height: 8),
            Text(t('Ctrl+S — حفظ نسخة', 'Ctrl+S — Save a copy')),
            const SizedBox(height: 8),
            Text(t('Ctrl+Tab — المستند التالي', 'Ctrl+Tab — Next tab')),
            const SizedBox(height: 8),
            Text(t('Ctrl+Shift+Tab — المستند السابق',
                'Ctrl+Shift+Tab — Previous tab')),
            const SizedBox(height: 14),
            Text(t(
              'قد يحتفظ المتصفح ببعض الاختصارات لنفسه. تعمل أزرار التطبيق أيضًا دون لوحة مفاتيح.',
              'Browsers may reserve some shortcuts. All commands are also available through buttons.',
            ), style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx),
          child: Text(t('إغلاق', 'Close'))),
      ],
    ),
  );

  Future<void> _showDetails() async {
    final session = _session;
    if (session == null) return;
    final size = (session.original.length / (1024 * 1024)).toStringAsFixed(2);
    final changed = (session.current.length / (1024 * 1024)).toStringAsFixed(2);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('معلومات المستند', 'Document details')),
        content: SizedBox(width: 400, child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(session.filename,
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(t('الصفحات: ${session.pageCount}',
                'Pages: ${session.pageCount}')),
            Text(t('حجم الملف الأصلي: $size ميجابايت',
                'Original size: $size MB')),
            Text(t('حجم النسخة الحالية: $changed ميجابايت',
                'Current size: $changed MB')),
            const SizedBox(height: 10),
            Text(session.isModified
                ? t('يوجد تعديل غير محفوظ', 'Unsaved changes')
                : t('لا توجد تعديلات غير محفوظة', 'No unsaved edits')),
            const SizedBox(height: 14),
            Text(t('تُعالج الملفات محليًا داخل الجهاز، ولا تُرفع إلى خادم.',
                'PDF files are processed locally and are not uploaded to a server.'),
                style: Theme.of(ctx).textTheme.bodySmall),
          ],
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: Text(t('إغلاق', 'Close'))),
        ],
      ),
    );
  }

  void _handleWorkspaceAction(_WorkspaceAction action) {
    switch (action) {
      case _WorkspaceAction.saveAll:
        unawaited(_saveAllModified());
        break;
      case _WorkspaceAction.close:
        final active = _documents.active;
        if (active != null) unawaited(_closeTab(active));
        break;
      case _WorkspaceAction.details:
        unawaited(_showDetails());
        break;
      case _WorkspaceAction.shortcuts:
        unawaited(_showShortcuts());
        break;
    }
  }

  Future<void> _addArabicText() async {
    final session = _session;
    if (session == null) return;
    if (_previewMode) setState(() => _previewMode = false);
    final text = TextEditingController();
    final page = TextEditingController(text: '1');
    final size = TextEditingController(text: '20');
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('إضافة نص عربي', 'Insert Arabic text')),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  autofocus: true,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(labelText: t('النص المطلوب', 'Text')),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(
                    controller: page,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: t('رقم الصفحة', 'Page number')),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(
                    controller: size,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: t('حجم الخط', 'Font size')),
                  )),
                ]),
                const SizedBox(height: 12),
                Text(
                  t('يُضاف النص كتعليق PDF قابل للتحرير دون تحويل الصفحة إلى صورة. يستخدم مسار Unicode مؤقتًا لتجنب عكس العربية، ولا يضمن تضمين خط Amiri أو تطابق المظهر في جميع برامج PDF. تحقق من النسخة المحفوظة في وضع PDFium.',
                    'Creates an editable PDF annotation without rasterization. The temporary Unicode path avoids reversed Arabic but does not guarantee embedded Amiri or identical appearance across PDF readers. Check the saved copy in PDFium.'),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('إلغاء', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('إضافة', 'Insert'))),
          ],
        ),
      );
      if (confirmed != true || !mounted || !_containsSession(session)) return;
      final parsedPage = int.tryParse(page.text.trim());
      final parsedSize = double.tryParse(size.text.trim());
      if (parsedPage == null || parsedSize == null || parsedSize < 8 || parsedSize > 72) {
        throw const FormatException('تأكد من رقم الصفحة وحجم الخط (8-72).');
      }
      session.addArabicText(
        text: text.text,
        pageIndex: parsedPage - 1,
        fontSize: parsedSize,
      );
      _toast(t('أُضيف النص؛ يمكنك تحريكه وتنسيقه ثم حفظ نسخة.',
          'Text inserted. Move or style it, then save a copy.'));
    } catch (error) {
      _toast('$error');
    } finally {
      text.dispose();
      page.dispose();
      size.dispose();
    }
  }

  Future<void> _showPageTools() async {
    final session = _session;
    if (session == null || _busy) return;
    final selected = session.controller.selectedPages;
    final request = await showPageToolsDialog(
      context,
      pageCount: session.pageCount,
      arabic: widget.arabic,
      initialPageIndex: selected.isNotEmpty ? selected.first : 0,
    );
    if (!mounted || request == null || !identical(_session, session)) return;

    if (request.action == PageToolAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('تأكيد حذف الصفحة', 'Delete page?')),
          content: Text(t(
            'سيتم حذف الصفحة من النسخة المعدلة. يمكن التراجع قبل إغلاق المستند، ولن يتغير الملف الأصلي.',
            'The page is removed from the edited copy. Undo is available until the document is closed; the original file is unchanged.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: Text(t('إلغاء', 'Cancel'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
                child: Text(t('حذف', 'Delete'))),
          ],
        ),
      );
      if (confirmed != true || !mounted || !identical(_session, session)) return;
    }

    setState(() => _busy = true);
    try {
      switch (request.action) {
        case PageToolAction.rotateLeft:
          session.rotatePage(request.pageIndex!, -90);
          break;
        case PageToolAction.rotateRight:
          session.rotatePage(request.pageIndex!, 90);
          break;
        case PageToolAction.duplicate:
          session.duplicatePage(request.pageIndex!);
          break;
        case PageToolAction.move:
          session.movePage(request.pageIndex!, request.destinationIndex!);
          break;
        case PageToolAction.delete:
          session.removePage(request.pageIndex!);
          break;
        case PageToolAction.blankAfter:
          session.addBlankPageAfter(request.pageIndex!);
          break;
        case PageToolAction.merge:
          final incoming = await _files.open();
          if (incoming == null || !mounted || !identical(_session, session)) return;
          session.appendPdf(incoming.bytes);
          break;
        case PageToolAction.extract:
          final bytes = session.extractPages(request.indices);
          final base = session.filename.toLowerCase().endsWith('.pdf')
              ? session.filename.substring(0, session.filename.length - 4)
              : session.filename;
          final count = request.indices.length;
          final saved = await _files.saveAs(
            bytes,
            session.filename,
            suggestedName: '$base-pages-$count.pdf',
          );
          if (saved) {
            _toast(t('تم تصدير الصفحات إلى PDF مستقل.',
                'Selected pages were exported into a new PDF.'));
          }
          return;
      }
      if (mounted) {
        setState(() => _previewMode = false);
        _toast(t('تم تنفيذ العملية. احفظ نسخة للاحتفاظ بالتغييرات.',
            'Operation completed. Save a copy to keep changes.'));
      }
    } catch (error) {
      _toast(t('تعذّر تنفيذ العملية: $error', 'Operation failed: $error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final session = _session;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            () => unawaited(_open()),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            () => unawaited(_save()),
        const SingleActivator(LogicalKeyboardKey.tab, control: true):
            () => _cycleTabs(),
        const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
            () => _cycleTabs(backwards: true),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: NahdaTheme.navy,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: NahdaTheme.gold),
            ),
            const SizedBox(width: 12),
            const Flexible(child: Text('Nahda PDF Studio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: widget.onSwitchLanguage,
            icon: const Icon(Icons.language_rounded, size: 19),
            label: Text(widget.arabic ? 'English' : 'العربية'),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE8ECF2)),
        ),
      ),
      body: Row(
        children: [
          if (wide) _sidebar(),
          Expanded(
            child: Column(
              children: [
                _toolbar(session, wide),
                if (_documents.count > 0) _tabStrip(),
                Expanded(child: session == null ? _emptyState() : _documentArea(session)),
                _statusBar(session),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _sidebar() => Container(
    width: 230,
    color: NahdaTheme.navy,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t('مساحة العمل', 'WORKSPACE').toUpperCase(),
          style: const TextStyle(color: NahdaTheme.gold, letterSpacing: 1.6, fontSize: 11)),
        const SizedBox(height: 22),
        _sideEntry(Icons.description_outlined, t('المستندات', 'Documents'), selected: true),
        const SizedBox(height: 14),
        Text(t('مستندات مفتوحة: ${_documents.count}/${_documents.maxTabs}',
          'Open PDFs: ${_documents.count}/${_documents.maxTabs}'),
          style: const TextStyle(color: Color(0xFFB8C5D4), fontSize: 12)),
        const SizedBox(height: 26),
        Text(t('قيد التطوير', 'COMING IN NEXT PHASES'),
          style: const TextStyle(color: Color(0xFF93A9BD), fontSize: 11)),
        const SizedBox(height: 12),
        Text(t('استبدال النص الأصلي • OCR • التشكيل العربي',
          'Original text replacement • OCR • Arabic shaping'),
          style: const TextStyle(color: Color(0xFFB8C5D4), fontSize: 12, height: 1.6)),
        const Spacer(),
        const Divider(color: Color(0xFF33475D)),
        const SizedBox(height: 12),
        Text(t('محلي وآمن • بدون رفع ملفات', 'OFFLINE-FIRST • NO UPLOADS'),
          style: const TextStyle(color: Color(0xFF9FADBC), fontSize: 11)),
        const SizedBox(height: 8),
        const Text('v0.3.0', style: TextStyle(color: Color(0xFF9FADBC))),
      ],
    ),
  );

  Widget _sideEntry(IconData icon, String label, {bool selected = false}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
    decoration: BoxDecoration(
      color: selected ? const Color(0xFF243D56) : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      border: selected ? BorderDirectional(start: BorderSide(color: NahdaTheme.gold, width: 3)) : null,
    ),
    child: Row(children: [
      Icon(icon, color: selected ? NahdaTheme.gold : const Color(0xFFB8C5D4), size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(
        color: selected ? Colors.white : const Color(0xFFCED8E4),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
      ))),
    ]),
  );

  Widget _tabStrip() {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F7FB),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E9F1))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Expanded(
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final tab in _documents.documents)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: SizedBox(
                    width: 224,
                    child: Material(
                      color: identical(_documents.active, tab)
                          ? Colors.white : const Color(0xFFE9EFF6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                        side: BorderSide(
                          color: identical(_documents.active, tab)
                              ? NahdaTheme.blue
                              : const Color(0xFFD7E1EB),
                        ),
                      ),
                      child: InkWell(
                        key: ValueKey('pdf-tab-${tab.id}'),
                        borderRadius: BorderRadius.circular(9),
                        onTap: _busy ? null : () =>
                            setState(() => _documents.activate(tab)),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 9),
                          child: Row(children: [
                            const Icon(Icons.picture_as_pdf_outlined,
                                size: 18, color: NahdaTheme.blue),
                            const SizedBox(width: 6),
                            Expanded(child: Tooltip(
                              message: tab.session.filename,
                              child: Text(
                                tab.session.filename,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            )),
                            if (tab.session.isModified)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 3),
                                child: Icon(Icons.circle,
                                    size: 8, color: Color(0xFFCA8B3C)),
                              ),
                            IconButton(
                              tooltip: t('إغلاق المستند', 'Close document'),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded, size: 17),
                              onPressed: _busy ? null :
                                  () => unawaited(_closeTab(tab)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filledTonal(
          tooltip: t('فتح مستند آخر', 'Open another PDF'),
          onPressed: _busy ? null : _open,
          icon: const Icon(Icons.add_rounded),
        ),
      ]),
    );
  }

  Widget _toolbar(DartPdfSession? session, bool wide) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _busy ? null : _open,
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: Text(t('فتح PDF', 'Open PDF')),
            style: FilledButton.styleFrom(backgroundColor: NahdaTheme.navy),
          ),
          FilledButton.tonalIcon(
            onPressed: session == null || _busy ? null : _addArabicText,
            icon: const Icon(Icons.format_size_rounded, size: 19),
            label: Text(t('إضافة نص عربي', 'Arabic text')),
          ),
          OutlinedButton.icon(
            onPressed: session == null || _busy ? null : _showPageTools,
            icon: const Icon(Icons.layers_outlined, size: 18),
            label: Text(t('إدارة الصفحات', 'Page tools')),
          ),
          OutlinedButton.icon(
            onPressed: session == null || _busy ? null : () => _save(),
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            label: Text(t('حفظ نسخة', 'Save copy')),
          ),
          PopupMenuButton<_WorkspaceAction>(
            tooltip: t('المزيد من الأدوات', 'More tools'),
            onSelected: _handleWorkspaceAction,
            icon: const Icon(Icons.more_horiz_rounded),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _WorkspaceAction.saveAll,
                enabled: !_busy &&
                    _documents.documents.any((tab) => tab.session.isModified),
                child: Text(t('حفظ نسخ من كل الملفات المعدّلة',
                    'Save all modified PDFs')),
              ),
              PopupMenuItem(
                value: _WorkspaceAction.close,
                enabled: !_busy && session != null,
                child: Text(t('إغلاق المستند الحالي', 'Close active PDF')),
              ),
              PopupMenuItem(
                value: _WorkspaceAction.details,
                enabled: session != null,
                child: Text(t('معلومات المستند', 'Document details')),
              ),
              PopupMenuItem(
                value: _WorkspaceAction.shortcuts,
                child: Text(t('اختصارات لوحة المفاتيح',
                    'Keyboard shortcuts')),
              ),
            ],
          ),
          if (session != null) ...[
            IconButton(
              tooltip: t('تراجع', 'Undo'),
              onPressed: session.canUndo && !_previewMode ? session.undo : null,
              icon: const Icon(Icons.undo_rounded),
            ),
            IconButton(
              tooltip: t('إعادة', 'Redo'),
              onPressed: session.canRedo && !_previewMode ? session.redo : null,
              icon: const Icon(Icons.redo_rounded),
            ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, icon: const Icon(Icons.edit_outlined, size: 17), label: Text(t('تحرير', 'Edit'))),
                ButtonSegment(value: true, icon: const Icon(Icons.visibility_outlined, size: 17), label: Text(t('PDFium', 'PDFium'))),
              ],
              selected: {_previewMode},
              onSelectionChanged: (v) => setState(() => _previewMode = v.first),
            ),
          ],
          if (_busy) const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 550),
      child: Card(
        color: Colors.white,
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FA),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined,
                    size: 48, color: NahdaTheme.blue),
              ),
              const SizedBox(height: 24),
              Text(t('مستنداتك، بدقة واحتراف', 'Your documents, precisely handled'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: NahdaTheme.ink, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Text(t(
                'افتح ملف PDF من جهازك، أدر الصفحات وأضف نصوصًا عربية، واحفظ نسخة جديدة دون تحويل الصفحات إلى صور.',
                'Open a PDF locally, manage pages, insert Arabic text and save a new copy without rasterizing pages.'),
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.7, color: Color(0xFF59687A)),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _open,
                icon: const Icon(Icons.add_rounded),
                label: Text(t('اختيار ملف PDF', 'Choose a PDF')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(190, 48),
                  backgroundColor: NahdaTheme.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _documentArea(DartPdfSession session) => Container(
    margin: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE2E9F1)),
    ),
    clipBehavior: Clip.antiAlias,
    child: _previewMode
      ? pdf_viewer.PdfViewer.data(
          session.current,
          sourceName: '${session.filename}#rev${session.controller.revisionId}',
          key: ValueKey('preview-${session.controller.revisionId}'),
        )
      : editor.PdfEditorView(
          key: ValueKey(session),
          controller: session.controller,
          onSave: (bytes) => unawaited(_saveSession(session, bytes)),
          onSaveAs: (bytes) => unawaited(_saveSession(session, bytes)),
          showSaveButton: false,
        ),
  );

  Widget _statusBar(DartPdfSession? session) => Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    child: Text(
      session == null
        ? t('لا يوجد مستند مفتوح  •  الملفات تبقى على جهازك',
          'No document open  •  Your files stay on device')
        : '${session.filename}  •  ${session.pageCount} ${t('صفحة', 'pages')}  •  '
          '${session.isModified ? t('تعديلات غير محفوظة', 'Unsaved edits') : t('المستند الأصلي', 'Original document')}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Color(0xFF657587), fontSize: 12),
    ),
  );
}

enum _CloseChoice { save, discard }

enum _WorkspaceAction { saveAll, close, details, shortcuts }
