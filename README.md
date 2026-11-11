# Nahda PDF Studio — المرحلة الأولى (v0.1.0)

محرر PDF محلي مبني باستخدام Flutter للويب وأندرويد، مع أدوات تحرير بالعربية وفحص جودة PDF عبر Python. **هذا مشروع مصدر حقيقي قابل للبناء، وليس APK أو خدمة منشورة حتى الآن.** لا يوجد خادم ولا API مدفوع ولا قاعدة بيانات. الكود مهيأ للتطوير على Windows باستخدام PowerShell.

## الوظائف المتاحة في كود المرحلة الأولى

- فتح ملفات PDF المختارة من الجهاز (حد أمان مبدئي 80MB).
- عارض PDFium مستقل لصفحات دقيقة وسريعة، ومحرر تفاعلي من `dart_pdf_editor`.
- واجهة حديثة تستجيب لحجم النافذة، عربية افتراضيًا ويمكن تحويلها للإنجليزية؛ ترجمة أدوات المحرر مُفعّلة.
- إضافة نص عربي على هيئة **تعليق PDF من نوع FreeText** بخط Amiri، قابل للتحريك والتعديل من المحرر.
- حفظ **نسخة جديدة** بدل الكتابة فوق الملف الأصلي، مع تحديث PDF تدريجي دون تسطيح الصفحة إلى صور.
- التراجع والإعادة، مع إمكانية استخدام أدوات البحث والتعليق وبعض إدارة الصفحات من المحرّر الأساسي.
- اختبارات آلية Python للتحقق من عدد الصفحات، الأبعاد، بقاء streams الأصلية والتحديث التدريجي، ومقارنة رندر اختياري بـPDFium.

**الأمانة التقنية:** وضع نص جديد داخل PDF **ليس** استبدالًا مؤكدًا لنص أصلي موجود ضمن content stream. تحرير النص الأصلي متعدد الخطوط أو المركب لا يزال مرحلة تجريبية قادمة. كما أن التوافق البصري للعربية (الربط، التشكيل، RTL، النسخ والبحث) ما زال بحاجة إلى اختبار على نسخة Flutter مبنية فعلًا.

## المتطلبات

- Windows 10 أو أحدث، PowerShell.
- Flutter **3.47.5** أو أحدث ضمن نفس السلسلة المتوافقة، Dart **3.13+**، Android SDK لإنتاج APK.
- Python 3.13 (لمحرّك الفحص فقط وليس لتشغيل واجهة Flutter).
- Git، واختياريًا GitHub CLI (`gh`) لإنشاء المستودع.
- إنترنت **أثناء التهيئة الأولى** لجلب الحزم وملف خط Amiri المفتوح المصدر. تُنفَّذ عمليات تحرير المستند محليًا. نشر الويب الثابت لا يحتاج خادم معالجة PDF، لكن توفر الموقع دون اتصال قبل إنشاء PWA ليس مضمونًا.

## تجهيز المشروع على Windows

فك ضغط المشروع إلى مجلد عمل مستقل، مثل `D:\Dev\nahda-pdf-studio`، ثم:

```powershell
cd D:\Dev\nahda-pdf-studio
flutter --version
.\scripts\bootstrap.ps1
```

يقوم السكربت **تلقائيًا** بتنزيل خط Amiri المرخّص SIL OFL ونص الترخيص على جهازك، وإنشاء مجلدات Flutter الرسمية للويب وأندرويد (غير المضمنة في الحزمة)، وتثبيت الحزم، وتشغيل `flutter analyze` واختبارات المتصفح باستخدام Chrome، وبناء نسخة Web. لا يشغّل السكربت اختبارات PDF الأصلية على Windows افتراضيًا، لأن `pdfium_dart` يحتاج MSVC وWindows SDK لهذه الاختبارات على مضيف Windows، بينما لا نحتاج بناء تطبيق Windows في المرحلة الأولى.

لاختبار محرك PDF الأصلي على جهاز Windows **اختياريًا** بعد تثبيت أدوات MSVC المجانية:

```powershell
.\scripts\bootstrap.ps1 -SkipFlutterCreate -RunNativePdfTests
```

يجري GitHub Actions أيضًا اختبار إدراج النص العربي في بيئة Linux المزودة بمترجم C/C++. عند فشل الاختبار الأصلي لا نعتبر جودة الإدراج معتمدة. لا نوزع الخط ضمن الحزمة.

تشغيل الويب:

```powershell
flutter run -d chrome
```

إنشاء موقع ثابت وAPK (بعد نجاح الاختبارات):

```powershell
flutter build web --release
flutter build apk --release
```

النتائج المتوقعة:
- `build\web\` ملفات الموقع الثابت.
- `build\app\outputs\flutter-apk\app-release.apk` ملف Android APK **غير موقّع بمفتاح توزيعك الشخصي** حتى تضبط توقيع الإصدار.

إذا تعذر تنفيذ سكربت PowerShell بسبب سياسة التشغيل استخدم `Set-ExecutionPolicy -Scope Process Bypass -Force` داخل الجلسة الحالية فقط، ثم أعد الأمر.

إذا سبق تنفيذ `flutter create`، تستطيع استخدام ` .\scripts\bootstrap.ps1 -SkipFlutterCreate `.

## تجربة Windows Desktop (اختبارية)

المشروع يدعم تجربة بناء Windows، لكن ملفات Windows المُولّدة بواسطة Flutter لا تُخزَّن في هذا المستودع بعد. لتوليدها وبناء التطبيق على Windows:

```powershell
cd D:\Dev\nahda-pdf-studio
git pull --ff-only origin main
.\scripts\build_windows.ps1
```

يفحص السكربت توفر مترجم Visual C++ وملف `atlstr.h` الخاص بـATL، ويُنشئ مجلد `windows/` فقط إن لم يكن موجودًا، ويثبّت الحزم ويُشغّل التطبيق. لفحص PDF الأصلي وبناء نسخة Release:

```powershell
.\scripts\build_windows.ps1 -RunNativeTest -Release
```

ملفات Windows الناتجة توجد في `build\windows\x64\runner\Release\`، ويجب توزيع المجلد بما فيه من DLL وبيانات، لا ملف EXE وحده. يوجد أيضًا سير عمل GitHub Actions مستقل لبناء Windows تحت `.github/workflows/windows-desktop.yml`؛ ينشر مخرجاته كـArtifact بعد نجاح الاختبارات. **اختبارات CI ليست بديلًا عن التجربة اليدوية على Windows 11.**

إذا ظهر الخطأ `atlstr.h` ففعّل `C++ ATL for latest v142 build tools (x86 & x64)` في Visual Studio 2019 Installer أو ما يعادله للإصدار المختار. وصول `flutter doctor` إلى `No issues found` لا يتحقق وحده من ATL. راجع [دليل Windows](docs/WINDOWS.md).

## تنبيه تجريبي — حروف العربية في FreeText

في Windows اكتُشف أن اختيار Amiri المضمّن افتراضيًا لدى `dart_pdf_editor 15.0.0` قد يعكس ترتيب الحروف العربية. ألغينا اختياره التلقائي، وتستخدم أداة إضافة النص العربي مسار Unicode مع حفظ النص المنطقي بدون عكس يدوي. **هذه معالجة مؤقتة لا تضمن تضمين Amiri أو التشكيل الصحيح عند فتح PDF في كل قارئ.** اختبر PDF بعد الحفظ في وضع PDFium وبرنامج مستقل قبل استخدامه مع العملاء؛ تفاصيل المعالجة في [معايير الجودة](docs/QA_AND_LIMITATIONS.md).

## تجربة إدراج النص العربي

1. شغّل التطبيق وافتح `tests/fixtures/vector_original.pdf`، وهو ملف متجه من صفحتين.
2. اختر **إضافة نص عربي**، واكتب `السلام عليكم ورحمة الله`، وحدد الصفحة 1 وحجم خط 18.
3. حرّك العنصر من واجهة التحرير ثم احفظ عبر **حفظ نسخة**. أعد فتح النسخة في عرض PDFium وفي Adobe Acrobat Reader عند توفره.
4. شغّل مقارنة الجودة (أدناه)، وراجع مظهر العربية، واتجاه الكلمات، والبحث ونسخ النص يدويًا. النجاح الآلي وحده **لا** يثبت جودة تشكيل العربية.

## اختبارات Python بعد الحفظ

```powershell
.\scripts\run_quality.ps1 -Before ".\tests\fixtures\vector_original.pdf" -After "D:\Path\vector_original-edited.pdf"
```

المقارنة تستخدم `--require-incremental` لأنها مخصصة لإضافة التعليقات غير الهدّامة، وتفشل إذا تغيّر محتوى الصفحات الأصلي. عند تعديل النص الأصلي نفسه في مرحلة لاحقة، سيختلف معيار الاختبار ويحتاج استراتيجية مقارنة لا ترفض التغيير المقصود.

للاختبارات الخاصة بوحدة Python:

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r tools\qa\requirements.txt
.\.venv\Scripts\python.exe -m unittest discover -s tests -p "test_*.py" -v
```

## GitHub

الوجهة الوحيدة لهذا المشروع: `sunnaalnahda/nahda-pdf-studio`. لا ترفع مجلد `Nahda-HR` هنا. لعمل مستودع جديد **خاص افتراضيًا** بعد التأكد من محتويات المجلد وتشغيل الاختبارات:

```powershell
winget install GitHub.cli
gh auth login
.\scripts\publish_github.ps1 -Visibility private
```

لجعله عامًا لاحقًا يمكنك تغيير `-Visibility public` **عند الإنشاء فقط**. السكربت يتوقف إذا كان المستودع موجودًا؛ لا يعدّل مستودعات أخرى.

## الملفات الرئيسة

```text
nahda-pdf-studio/
  lib/
    main.dart                            # التهيئة والترجمة
    app/theme.dart                       # نظام الألوان
    core/pdf/editing_engine.dart         # عقد المحرك المستقل
    core/pdf/dart_pdf_engine.dart        # تكييف dart_pdf_editor
    core/pdf/local_file_repository.dart  # فتح وحفظ دون خادم
    features/workspace/workspace_page.dart
  assets/fonts/.gitkeep                  # الخط يُنزّل عند التهيئة
  tests/fixtures/vector_original.pdf     # ملف PDF متجه للقياس
  test/                                 # اختبارات Flutter
  tools/qa/                             # مقارن PDF عبر Python
  tests/                                # اختبارات Python
  docs/                                 # معمارية، تراخيص، حدود الجودة
  scripts/                              # تهيئة/فحص/نشر GitHub
  .github/workflows/quality.yml         # CI
```

### بوابات الانتقال إلى المرحلة الثانية

لا نعتمد المرحلة الأولى صالحة للاستخدام اليومي إلا بعد نجاح: `flutter analyze`، واختبارات Chrome، واختبار إدراج النص الأصلي في Linux أو Android، و`flutter build web --release`، و`flutter build apk --release`، وفتح عينة PDF على Chrome وجهاز Android فعلي، وحفظها وإعادة فتحها، وفحص اختلاف الشكل العربي بصريًا عبر PDFium ومحرر Dart، ومقارنة نسخة `-edited.pdf` بـPython.

راجع [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) و[`docs/THIRD_PARTY.md`](docs/THIRD_PARTY.md) و[`docs/QA_AND_LIMITATIONS.md`](docs/QA_AND_LIMITATIONS.md).
