# Nahda PDF Studio — Windows Desktop

## حالة المنصة
- **الهدف:** نسخة سطح مكتب Windows مبنية من واجهة Flutter المشتركة ومحرك PDF المحلي.
- **الوضع الحالي:** مسار بناء واختبار Windows مضاف إلى GitHub. نجاح البناء الآلي لا يثبت سلامة عرض كل ملفات PDF أو صحة تشكيل العربية.
- **سبب عطل المستخدم السابق:** `flutter_secure_storage_windows` احتاج `atlstr.h` من حزمة ATL، وهي ليست ضمن الحد الأدنى الذي يفحصه `flutter doctor`.
- **لا حاجة** إلى إعادة تثبيت Flutter أو Android أو Python لإصلاح هذه المكتبة.

## المتطلبات
1. Windows 10/11 x64 وإصدار Flutter متوافق (استُخدم Flutter 3.47.5).
2. Visual Studio يتضمن Desktop development with C++ وMSVC وCMake وWindows SDK.
3. **ATL لإصدار MSVC المستخدم في البناء**. في Visual Studio 2019: `C++ ATL for latest v142 build tools (x86 & x64)`. يمكن العثور على `atlstr.h` عادة داخل `VC\Tools\MSVC\<version>\atlmfc\include\`.
4. خط Amiri بترخيص SIL OFL (السكربت ينزّل الخط وإشعار الترخيص عند غيابهما).
5. إنترنت عند التهيئة الأولى لتثبيت حزم Dart والملفات المرخصة. تحرير PDF محلي ولا يحتاج خادمًا.

## خطوات Windows

```powershell
cd D:\Dev\nahda-pdf-studio
git pull --ff-only origin main
.\scripts\build_windows.ps1
```

السكريبت يتحقق من وجود ATL ثم ينشئ `windows/` إذا كان غير موجود ويحلّل المشروع ويشغّل التطبيق في وضع Debug.

لإجراء اختبار PDF الأصلي وبناء نسخة Release:

```powershell
.\scripts\build_windows.ps1 -RunNativeTest -Release
```

ولعرض الأجهزة المتاحة:

```powershell
flutter devices
```

## التوزيع
بعد `flutter build windows --release` احفظ **مجلد Release بالكامل** بما فيه DLL والبيانات؛ لا توزّع ملف EXE منفردًا. مخرجات بناء GitHub Actions هي حزم اختبارية وليست إصدارًا موقّعًا أو مثبّت MSI/MSIX حتى الآن.

## المشاكل الشائعة
- `fatal error C1083: 'atlstr.h'`: ثبّت ATL لإصدار Visual Studio الذي اختاره البناء، ثم أعد فتح VS Code وأعد `flutter run -d windows`. إن استمر الفشل، نفذ `flutter clean` ثم `flutter pub get`.
- `warning C4090` في تبعية `jni`: تحذير منفصل؛ ليس السبب الأصلي لفشل البناء، ويحتاج مراجعة إصدار التبعية إذا استمر.
- `flutter doctor` ناجح لكن البناء يفشل: Flutter لا يفحص ATL؛ افحص ملف الترويسة ضمن الأدوات المختارة وسجل البناء التفصيلي.

## تحقق الجودة
1. فتح `tests/fixtures/vector_original.pdf`.
2. إضافة النص `السَّلامُ عَلَيْكُم وَرَحْمَةُ اللهِ ١٢٣` للصفحة الأولى.
3. حفظ نسخة ثم فتحها مجددًا في عرض PDFium وفي قارئ مستقل.
4. التحقق من ظهور الحروف متصلة والتشكيل الصحيح وعدم تغيير الرسومات الأصلية.
5. مقارنة الملفات باستخدام `scripts/run_quality.ps1`.

النجاح في اختبار PDF البنيوي وحده لا يكفي لضمان التشكيل أو الأداء أو سلامة كل الخطوط. ولا تزال هناك حاجة لاختبارات Windows 11 اليدوية واختبارات ملفات عربية أكثر تعقيدًا.
