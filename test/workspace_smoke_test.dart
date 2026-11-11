import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nahda_pdf_studio/main.dart';

void main() {
  testWidgets('Nahda PDF Studio opens the Arabic workspace', (tester) async {
    // Desktop-like viewport prevents small-test-window overflow.
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() async => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const NahdaPdfStudio());
    await tester.pumpAndSettle();

    expect(find.text('Nahda PDF Studio'), findsOneWidget);
    expect(find.text('فتح PDF'), findsOneWidget);
    expect(find.text('اختيار ملف PDF'), findsOneWidget);
  });
}
