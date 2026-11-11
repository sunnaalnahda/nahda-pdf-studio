import 'package:dart_pdf_editor/dart_pdf_editor.dart' show DartPdfEditorLocalizations;
import 'package:dart_pdf_editor_assets/dart_pdf_editor_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pdfrx/pdfrx.dart' as pdf_viewer;

import 'app/theme.dart';
import 'features/workspace/workspace_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerBundledEditorAssets();
  await pdf_viewer.pdfrxFlutterInitialize();
  runApp(const NahdaPdfStudio());
}

class NahdaPdfStudio extends StatefulWidget {
  const NahdaPdfStudio({super.key});

  @override
  State<NahdaPdfStudio> createState() => _NahdaPdfStudioState();
}

class _NahdaPdfStudioState extends State<NahdaPdfStudio> {
  bool _arabic = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nahda PDF Studio',
      debugShowCheckedModeBanner: false,
      locale: Locale(_arabic ? 'ar' : 'en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        DartPdfEditorLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: NahdaTheme.light,
      home: Directionality(
        textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
        child: WorkspacePage(
          arabic: _arabic,
          onSwitchLanguage: () => setState(() => _arabic = !_arabic),
        ),
      ),
    );
  }
}
