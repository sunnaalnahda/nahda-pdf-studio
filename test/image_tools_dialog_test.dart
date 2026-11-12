import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/core/pdf/image_info.dart';
import 'package:nahda_pdf_studio/core/pdf/image_placement.dart';
import 'package:nahda_pdf_studio/features/workspace/image_tools_dialog.dart';

void main() {
  testWidgets('Image insertion dialog returns a safe positioned request',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0k'
      'AAAAGUlEQVR4nGP4z8DwHwgbWBgZ/jNyicr7AgA3BAUOTnqjAAAAAABJRU5ErkJggg==',
    );
    ImageInsertRequest? request;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () async {
          request = await showInsertImageDialog(
            context,
            imageBytes: bytes,
            info: PdfImageInfo.inspect(bytes),
            filename: 'sample.png',
            pageCount: 5,
            arabic: true,
          );
        },
        child: const Text('open'),
      ))),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('إدراج صورة داخل PDF'), findsOneWidget);
    expect(find.text('sample.png'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '٣');
    await tester.tap(find.text('إدراج الصورة'));
    await tester.pumpAndSettle();
    expect(request, isNotNull);
    expect(request!.pageIndex, 2);
    expect(request!.placement.position, PdfImagePosition.center);
  });
}
