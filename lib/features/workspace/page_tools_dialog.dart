import 'package:flutter/material.dart';

import '../../core/pdf/page_selection.dart';

enum PageToolAction {
  rotateLeft,
  rotateRight,
  duplicate,
  move,
  delete,
  blankAfter,
  merge,
  extract,
}

class PageToolRequest {
  const PageToolRequest(this.action, {
    this.pageIndex,
    this.destinationIndex,
    this.indices = const [],
  });

  final PageToolAction action;
  final int? pageIndex;
  final int? destinationIndex;
  final List<int> indices;
}

Future<PageToolRequest?> showPageToolsDialog(
  BuildContext context, {
  required int pageCount,
  required bool arabic,
  int initialPageIndex = 0,
}) => showDialog<PageToolRequest>(
  context: context,
  builder: (context) => PageToolsDialog(
    pageCount: pageCount,
    arabic: arabic,
    initialPageIndex: initialPageIndex,
  ),
);

class PageToolsDialog extends StatefulWidget {
  const PageToolsDialog({
    super.key,
    required this.pageCount,
    required this.arabic,
    this.initialPageIndex = 0,
  });

  final int pageCount;
  final bool arabic;
  final int initialPageIndex;

  @override
  State<PageToolsDialog> createState() => _PageToolsDialogState();
}

class _PageToolsDialogState extends State<PageToolsDialog> {
  late final TextEditingController _page;
  late final TextEditingController _destination;
  late final TextEditingController _range;
  String? _error;

  String tr(String ar, String en) => widget.arabic ? ar : en;

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialPageIndex + 1).clamp(1, widget.pageCount);
    _page = TextEditingController(text: '$initial');
    _destination = TextEditingController(text: '$initial');
    _range = TextEditingController(text: '1-${widget.pageCount}');
  }

  @override
  void dispose() {
    _page.dispose();
    _destination.dispose();
    _range.dispose();
    super.dispose();
  }

  void _submit(PageToolAction action) {
    try {
      final requiresPage = action != PageToolAction.merge &&
          action != PageToolAction.extract;
      final page = requiresPage
          ? PdfPageSelection.page(_page.text, widget.pageCount)
          : null;
      final destination = action == PageToolAction.move
          ? PdfPageSelection.page(_destination.text, widget.pageCount)
          : null;
      final indices = action == PageToolAction.extract
          ? PdfPageSelection.parse(_range.text, widget.pageCount)
          : const <int>[];
      if (action == PageToolAction.delete && widget.pageCount == 1) {
        throw FormatException(tr(
          'لا يمكن حذف آخر صفحة في المستند.',
          'The document must contain at least one page.',
        ));
      }
      Navigator.of(context).pop(PageToolRequest(
        action,
        pageIndex: page,
        destinationIndex: destination,
        indices: indices,
      ));
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Widget _field(String title, TextEditingController controller, {
    String? hint,
  }) => TextField(
    controller: controller,
    textDirection: TextDirection.ltr,
    decoration: InputDecoration(labelText: title, hintText: hint),
  );

  Widget _operation(
    String title,
    IconData icon,
    PageToolAction action, {
    bool destructive = false,
  }) => OutlinedButton.icon(
    onPressed: () => _submit(action),
    icon: Icon(icon, size: 19),
    label: Text(title),
    style: destructive
        ? OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          )
        : null,
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.layers_outlined),
        const SizedBox(width: 10),
        Expanded(child: Text(tr('أدوات إدارة الصفحات', 'Document page tools'))),
      ]),
      content: SizedBox(
        width: 590,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('جميع العمليات محلية وتحافظ على عناصر PDF الأصلية.',
                   'All operations run locally without rasterizing the document.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              _field(tr('رقم الصفحة', 'Page number'), _page),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _operation(tr('تدوير يمين', 'Rotate right'),
                    Icons.rotate_right, PageToolAction.rotateRight),
                _operation(tr('تدوير يسار', 'Rotate left'),
                    Icons.rotate_left, PageToolAction.rotateLeft),
                _operation(tr('تكرار الصفحة', 'Duplicate'),
                    Icons.control_point_duplicate, PageToolAction.duplicate),
                _operation(tr('إضافة صفحة فارغة بعدها', 'Insert blank after'),
                    Icons.note_add_outlined, PageToolAction.blankAfter),
                _operation(tr('حذف الصفحة', 'Delete page'),
                    Icons.delete_outline, PageToolAction.delete,
                    destructive: true),
              ]),
              const SizedBox(height: 16),
              _field(tr('انقل الصفحة إلى الموضع', 'Move page to position'),
                  _destination),
              const SizedBox(height: 7),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _operation(tr('نقل الصفحة', 'Move page'),
                    Icons.swap_vert, PageToolAction.move),
              ),
              const Divider(height: 28),
              Text(tr('الدمج والاستخراج', 'Merge and extract'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _field(tr('الصفحات المراد استخراجها', 'Pages to export'),
                  _range, hint: '1-3,5,8-10'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _operation(tr('تصدير صفحات مختارة', 'Export selected pages'),
                    Icons.file_download_outlined, PageToolAction.extract),
                _operation(tr('دمج ملف PDF آخر', 'Append another PDF'),
                    Icons.merge_type_outlined, PageToolAction.merge),
              ]),
              const SizedBox(height: 9),
              Text(tr(
                'اكتب أرقامًا مثل ١-٣،٥. يحتفظ الاستخراج بترتيب الصفحات المكتوب. الحذف قابل للتراجع ما لم تغلق المستند.',
                'Use ranges such as 1-3,5. Extraction follows the order entered. You can undo deletion while the document is open.',
              ), style: Theme.of(context).textTheme.bodySmall),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                )),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('إغلاق', 'Close')),
        ),
      ],
    );
  }
}
