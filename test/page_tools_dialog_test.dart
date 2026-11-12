import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/features/workspace/page_tools_dialog.dart';

void main() {
  testWidgets('Page tools exposes valid export request and validates range',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    PageToolRequest? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () async {
            result = await showPageToolsDialog(
              context,
              pageCount: 5,
              arabic: false,
            );
          },
          child: const Text('Open tools'),
        )),
      ),
    ));
    await tester.tap(find.text('Open tools'));
    await tester.pumpAndSettle();
    expect(find.text('Document page tools'), findsOneWidget);

    final input = find.byType(TextField).last;
    await tester.enterText(input, '١-٣،٥');
    await tester.tap(find.text('Export selected pages'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.action, PageToolAction.extract);
    expect(result!.indices, [0, 1, 2, 4]);
  });
}
