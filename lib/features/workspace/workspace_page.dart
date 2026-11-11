import 'dart:async';
import 'dart:typed_data';
import 'package:dart_pdf_editor/dart_pdf_editor.dart' as editor;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart' as pdf_viewer;

import '../../app/theme.dart';
import '../../core/pdf/dart_pdf_engine.dart';
import '../../core/pdf/local_file_repository.dart';

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
  DartPdfSession? _session;
  bool _busy = false;
  bool _previewMode = false;

  String t(String ar, String en) => widget.arabic ? ar : en;

  @override
  void dispose() {
    _session?.controller.removeListener(_documentChanged);
    _session?.dispose();
    super.dispose();
  }

  void _documentChanged() {
    if (mounted) setState(() {});
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _open() async {
    if (_busy) return;
    if (_session?.isModified ?? false) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t('تعديلات لم تُحفظ', 'Unsaved changes')),
          content: Text(t(
            'احفظ نسخة من المستند الحالي قبل فتح ملف آخر، أو تابع دون حفظ.',
            'Save your current edits before opening another file, or discard them.',
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t('إلغاء', 'Cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t('متابعة دون حفظ', 'Discard'))),
          ],
        ),
      );
      if (discard != true) return;
    }
    setState(() => _busy = true);
    try {
      final selected = await _files.open();
      if (selected == null) return;
      final opened = await _engine.open(filename: selected.name, data: selected.bytes);
      if (!mounted) {
        opened.dispose();
        return;
      }
      _session?.controller.removeListener(_documentChanged);
      _session?.dispose();
      opened.controller.addListener(_documentChanged);
      setState(() {
        _session = opened;
        _previewMode = false;
      });
    } catch (error) {
      _toast(t('فشل فتح الملف: $error', 'Unable to open PDF: $error'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save([Uint8List? editedBytes]) async {
    final session = _session;
    if (session == null || _busy) return;
    setState(() => _busy = true);
    try {
      final saved = await _files.saveAs(editedBytes ?? session.current, session.filename);
      if (saved) {
        session.markSaved();
        if (mounted) setState(() {});
        _toast(t('تم حفظ نسخة جديدة من المستند.', 'A new PDF copy was saved.'));
      }
    } catch (error) {
      _toast(t('تعذر حفظ الملف: $error', 'Unable to save PDF: $error'));
    } finally {
      if (mounted) setState(() => _busy = false);
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
                  t('يُضاف النص كعنصر PDF متجه وقابل للتحريك، مع إبقاء محتوى الصفحة الأصلي.',
                    'Text is added as an editable vector PDF annotation without rasterizing the page.'),
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
      if (confirmed != true) return;
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

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final session = _session;
    return Scaffold(
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
                Expanded(child: session == null ? _emptyState() : _documentArea(session)),
                _statusBar(session),
              ],
            ),
          ),
        ],
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
        const SizedBox(height: 26),
        Text(t('قيد التطوير', 'COMING IN NEXT PHASES'),
          style: const TextStyle(color: Color(0xFF93A9BD), fontSize: 11)),
        const SizedBox(height: 12),
        Text(t('استبدال النص الأصلي • إدارة الصفحات • OCR',
          'Original text replacement • Page tools • OCR'),
          style: const TextStyle(color: Color(0xFFB8C5D4), fontSize: 12, height: 1.6)),
        const Spacer(),
        const Divider(color: Color(0xFF33475D)),
        const SizedBox(height: 12),
        Text(t('محلي وآمن • بدون رفع ملفات', 'OFFLINE-FIRST • NO UPLOADS'),
          style: const TextStyle(color: Color(0xFF9FADBC), fontSize: 11)),
        const SizedBox(height: 8),
        const Text('v0.1.0', style: TextStyle(color: Color(0xFF9FADBC))),
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
            onPressed: session == null || _busy ? null : () => _save(),
            icon: const Icon(Icons.save_alt_rounded, size: 18),
            label: Text(t('حفظ نسخة', 'Save copy')),
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
                'افتح ملف PDF من جهازك، أضف نصوصًا عربية بخط مضمّن، واحفظ نسخة جديدة دون تحويل الصفحات إلى صور.',
                'Open a PDF locally, insert embedded Arabic text and save a new copy without rasterizing pages.'),
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
          onSave: (bytes) => unawaited(_save(bytes)),
          onSaveAs: (bytes) => unawaited(_save(bytes)),
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
