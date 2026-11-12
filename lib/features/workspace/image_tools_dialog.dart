import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/pdf/image_info.dart';
import '../../core/pdf/image_placement.dart';
import '../../core/pdf/page_selection.dart';

class ImageInsertRequest {
  const ImageInsertRequest({
    required this.pageIndex,
    required this.placement,
  });

  final int pageIndex;
  final PdfImagePlacement placement;
}

Future<ImageInsertRequest?> showInsertImageDialog(
  BuildContext context, {
  required Uint8List imageBytes,
  required PdfImageInfo info,
  required String filename,
  required int pageCount,
  required bool arabic,
}) => showDialog<ImageInsertRequest>(
  context: context,
  builder: (context) => _InsertImageDialog(
    bytes: imageBytes,
    info: info,
    filename: filename,
    pageCount: pageCount,
    arabic: arabic,
  ),
);

class _InsertImageDialog extends StatefulWidget {
  const _InsertImageDialog({
    required this.bytes,
    required this.info,
    required this.filename,
    required this.pageCount,
    required this.arabic,
  });

  final Uint8List bytes;
  final PdfImageInfo info;
  final String filename;
  final int pageCount;
  final bool arabic;

  @override
  State<_InsertImageDialog> createState() => _InsertImageDialogState();
}

class _InsertImageDialogState extends State<_InsertImageDialog> {
  final _page = TextEditingController(text: '1');
  final _size = TextEditingController(text: '220');
  PdfImagePosition _position = PdfImagePosition.center;
  double _opacity = 1;
  String? _error;

  String t(String ar, String en) => widget.arabic ? ar : en;

  @override
  void dispose() {
    _page.dispose();
    _size.dispose();
    super.dispose();
  }

  String _label(PdfImagePosition position) => switch (position) {
    PdfImagePosition.center => t('وسط الصفحة', 'Center'),
    PdfImagePosition.topLeft => t('أعلى اليسار', 'Top left'),
    PdfImagePosition.topRight => t('أعلى اليمين', 'Top right'),
    PdfImagePosition.bottomLeft => t('أسفل اليسار', 'Bottom left'),
    PdfImagePosition.bottomRight => t('أسفل اليمين', 'Bottom right'),
  };

  void _confirm() {
    try {
      final index = PdfPageSelection.page(_page.text, widget.pageCount);
      final side = double.tryParse(_size.text.trim());
      if (side == null || side < 24 || side > 2000) {
        throw const FormatException('حجم الصورة يجب أن يكون 24-2000 نقطة.');
      }
      Navigator.pop(context, ImageInsertRequest(
        pageIndex: index,
        placement: PdfImagePlacement(
          maxSidePoints: side,
          position: _position,
          opacity: _opacity,
        ),
      ));
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lengthKb = (widget.info.length / 1024).toStringAsFixed(1);
    return AlertDialog(
      title: Text(t('إدراج صورة داخل PDF', 'Insert image into PDF')),
      content: SizedBox(
        width: 510,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 168,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.memory(
                  widget.bytes,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, trace) =>
                      const Icon(Icons.broken_image_outlined, size: 42),
                ),
              ),
              const SizedBox(height: 12),
              Text(widget.filename,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
              Text(
                '${widget.info.width} × ${widget.info.height} px • $lengthKb KB',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: TextField(
                  controller: _page,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: t('رقم الصفحة', 'Page number'),
                    helperText: t(
                      'من 1 إلى ${widget.pageCount}',
                      'From 1 to ${widget.pageCount}',
                    ),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _size,
                  textDirection: TextDirection.ltr,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: t('أكبر ضلع بالنقاط', 'Max side (pt)'),
                    helperText: t('72 نقطة = بوصة', '72 pt = one inch'),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<PdfImagePosition>(
                initialValue: _position,
                decoration: InputDecoration(
                  labelText: t('مكان الصورة', 'Image position'),
                ),
                items: [
                  for (final position in PdfImagePosition.values)
                    DropdownMenuItem(
                      value: position,
                      child: Text(_label(position)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _position = value);
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Text(t('الشفافية', 'Opacity'))),
                Text('${(_opacity * 100).round()}%'),
              ]),
              Slider(
                value: _opacity,
                min: 0.1,
                max: 1,
                divisions: 18,
                label: '${(_opacity * 100).round()}%',
                onChanged: (v) => setState(() => _opacity = v),
              ),
              Text(t(
                'تُضمّن الصورة كعنصر مستقل قابل للتحريك والتكبير والقص. لا تتحول صفحة PDF الأصلية إلى صورة.',
                'Adds an independent, movable, resizable and croppable image. The original PDF page is not rasterized.',
              ), style: Theme.of(context).textTheme.bodySmall),
              if (_error != null) ...[
                const SizedBox(height: 8),
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
          onPressed: () => Navigator.pop(context),
          child: Text(t('إلغاء', 'Cancel')),
        ),
        FilledButton.icon(
          onPressed: _confirm,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(t('إدراج الصورة', 'Insert image')),
        ),
      ],
    );
  }
}

enum ImageEditAction {
  rotateLeft,
  rotateRight,
  resize,
  crop,
  resetCrop,
  opacity,
  moveLeft,
  moveRight,
  moveUp,
  moveDown,
  delete,
}

class ImageEditRequest {
  const ImageEditRequest(this.action, {this.value = 0, this.crop = const [0, 0, 0, 0]});

  final ImageEditAction action;
  final double value;
  /// Fractions in order: left, right, top, bottom.
  final List<double> crop;
}

Future<ImageEditRequest?> showImageEditDialog(
  BuildContext context, {
  required bool arabic,
  required bool canCrop,
  required double currentOpacity,
}) => showDialog<ImageEditRequest>(
  context: context,
  builder: (ctx) => _EditImageDialog(
    arabic: arabic,
    canCrop: canCrop,
    currentOpacity: currentOpacity,
  ),
);

class _EditImageDialog extends StatefulWidget {
  const _EditImageDialog({
    required this.arabic,
    required this.canCrop,
    required this.currentOpacity,
  });

  final bool arabic;
  final bool canCrop;
  final double currentOpacity;

  @override
  State<_EditImageDialog> createState() => _EditImageDialogState();
}

class _EditImageDialogState extends State<_EditImageDialog> {
  final _size = TextEditingController(text: '220');
  final _left = TextEditingController(text: '10');
  final _right = TextEditingController(text: '10');
  final _top = TextEditingController(text: '10');
  final _bottom = TextEditingController(text: '10');
  String? _error;
  late double _opacity = widget.currentOpacity.clamp(0.1, 1).toDouble();

  String t(String ar, String en) => widget.arabic ? ar : en;

  @override
  void dispose() {
    _size.dispose();
    _left.dispose();
    _right.dispose();
    _top.dispose();
    _bottom.dispose();
    super.dispose();
  }

  void _submit(ImageEditAction action) {
    try {
      var value = 0.0;
      var crop = const <double>[0, 0, 0, 0];
      if (action == ImageEditAction.resize) {
        value = double.tryParse(_size.text.trim()) ?? -1;
        if (!value.isFinite || value < 12 || value > 2000) {
          throw const FormatException('حدد حجمًا بين 12 و2000 نقطة.');
        }
      }
      if (action == ImageEditAction.opacity) value = _opacity;
      if (action == ImageEditAction.crop) {
        final values = [_left, _right, _top, _bottom].map(
          (controller) => (double.tryParse(controller.text.trim()) ?? -1) / 100,
        ).toList();
        if (values.any((n) => !n.isFinite || n < 0 || n > 0.9) ||
            values[0] + values[1] >= 0.95 ||
            values[2] + values[3] >= 0.95) {
          throw const FormatException('نسب القص غير صحيحة.');
        }
        crop = values;
      }
      Navigator.pop(context,
          ImageEditRequest(action, value: value, crop: crop));
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Widget _action(String title, IconData icon, ImageEditAction action) =>
      OutlinedButton.icon(
        onPressed: () => _submit(action),
        icon: Icon(icon, size: 18),
        label: Text(title),
      );

  Widget _ratioField(String title, TextEditingController controller) =>
      SizedBox(
        width: 100,
        child: TextField(
          controller: controller,
          textDirection: TextDirection.ltr,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: title, suffixText: '%'),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t('تعديل الصورة المحددة', 'Edit selected image')),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('تدوير وتحريك', 'Rotate and move'),
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _action(t('يمين 90°', 'Right 90°'), Icons.rotate_right,
                    ImageEditAction.rotateRight),
                _action(t('يسار 90°', 'Left 90°'), Icons.rotate_left,
                    ImageEditAction.rotateLeft),
                _action(t('يمين 10pt', 'Right 10pt'), Icons.arrow_forward,
                    ImageEditAction.moveRight),
                _action(t('يسار 10pt', 'Left 10pt'), Icons.arrow_back,
                    ImageEditAction.moveLeft),
                _action(t('أعلى 10pt', 'Up 10pt'), Icons.arrow_upward,
                    ImageEditAction.moveUp),
                _action(t('أسفل 10pt', 'Down 10pt'), Icons.arrow_downward,
                    ImageEditAction.moveDown),
              ]),
              const Divider(height: 30),
              Text(t('الحجم', 'Resize'),
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 7),
              Row(children: [
                Expanded(child: TextField(
                  controller: _size,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: t('أكبر ضلع بالنقاط', 'Longest side (pt)'),
                  ),
                )),
                const SizedBox(width: 10),
                _action(t('تطبيق الحجم', 'Resize'), Icons.aspect_ratio,
                    ImageEditAction.resize),
              ]),
              const Divider(height: 30),
              Text(t('قص الصورة بالنسبة المئوية من الحواف',
                  'Crop percentages from image edges'),
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _ratioField(t('يسار', 'Left'), _left),
                _ratioField(t('يمين', 'Right'), _right),
                _ratioField(t('أعلى', 'Top'), _top),
                _ratioField(t('أسفل', 'Bottom'), _bottom),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: widget.canCrop
                      ? () => _submit(ImageEditAction.crop) : null,
                  icon: const Icon(Icons.crop),
                  label: Text(t('قص الصورة', 'Crop')),
                ),
                OutlinedButton.icon(
                  onPressed: widget.canCrop
                      ? () => _submit(ImageEditAction.resetCrop) : null,
                  icon: const Icon(Icons.restart_alt),
                  label: Text(t('إلغاء القص السابق', 'Reset crop')),
                ),
              ]),
              const Divider(height: 30),
              Text(t('الشفافية', 'Opacity')),
              Row(children: [
                Expanded(child: Slider(
                  value: _opacity,
                  min: 0.1,
                  max: 1,
                  divisions: 18,
                  onChanged: (v) => setState(() => _opacity = v),
                )),
                Text('${(_opacity * 100).round()}%'),
              ]),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _action(t('تطبيق الشفافية', 'Apply opacity'),
                    Icons.opacity, ImageEditAction.opacity),
              ),
              const SizedBox(height: 12),
              Text(t(
                'يعمل التحرير على الصورة المحددة من نوع Stamp. يمكن أيضًا تحريكها وتكبيرها مباشرة بمقابض المحرّر.',
                'Edits the selected Stamp image. You can also drag and resize it directly using editor handles.',
              ), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _submit(ImageEditAction.delete),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(t('حذف الصورة المحددة', 'Delete selected image')),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
              if (_error != null)
                Text(_error!, style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('إغلاق', 'Close')),
        ),
      ],
    );
  }
}
