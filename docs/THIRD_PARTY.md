# مراجعة ترخيص المكونات — 11 نوفمبر 2026

جميع المكتبات التالية مرشحة/معتمدة على أساس تراخيص مجانية مفتوحة المصدر وليست SDK تجارية. النسخ المباشرة مثبتة في `pubspec.yaml`، ويجب التحقق من **التبعيات غير المباشرة وإشعارات ملفات الخطوط وPDFium** ضمن بوابة الإصدار. لا يحمل هذا المستند ترخيصًا لمشروعنا نفسه ولا يمثل رأيًا قانونيًا.

| المكوّن | الإصدار/المرحلة | الترخيص المنشور | القرار |
|---|---|---|---|
| Flutter | SDK، >=3.47 | BSD-3-Clause | معتمد |
| `pdfrx` | 2.12.0 | MIT | معتمد لمعاينة PDFium |
| PDFium / `pdfrx_engine` | تابع للعارض | PDFium BSD-style + إشعارات طرف ثالث | معتمد مشروط بجمع الإشعارات |
| `dart_pdf_editor` | 15.0.0 | Apache-2.0 | معتمد كتجربة تطوير، يحتاج اختبار عربي على الأجهزة |
| `dart_pdf_editor_assets` | 15.0.0 | Apache-2.0 للحزمة؛ الخطوط تراخيص متعددة | معتمد، مع تضمين إشعارات الخطوط عند التوزيع |
| `file_picker` | 13.3.3 | MIT | معتمد |
| `pdf_document`/`pdf_cos` | تبعيات `dart_pdf_editor` | Apache-2.0 (تحقق من الإصدارات المُقفلة) | غير مباشر، قبل النشر تدقيق lockfile |
| Amiri | تنزيل أثناء `bootstrap.ps1` | SIL Open Font License 1.1 | معتمد؛ يتم حفظ `OFL.txt` عند التنزيل |
| `pypdf` | >=5.9,<7 | BSD-3-Clause | QA محلي |
| `pypdfium2` | >=4.30,<6 | Apache-2.0 وحقوق/إشعارات PDFium | QA محلي |
| `Pillow` | >=11,<13 | HPND | QA محلي |
| `reportlab` | >=4,<5 | BSD-style | مولد اختبارات محلي |
| `pikepdf` | اختياري >=10,<12 | MPL-2.0 | QA إضافي، لا يُضمَّن في التطبيق |
| `pdf-lib` | غير مستخدم الآن | MIT | بديل JS محتمل يضيف ازدواجية |
| `pdfcpu` | غير مستخدم الآن | Apache-2.0 | بديل دمج/تقسيم في أداة CLI، ليس Flutter Web |
| `PDF.js` | غير مستخدم الآن | Apache-2.0 | بديل Web renderer، لا حاجة الآن |
| `Tesseract OCR` | مخطط لاحقًا | Apache-2.0 | دراسة Android + Web WASM لاحقًا |

**مهم بشأن `dart_pdf_editor_assets`:** خطوط DejaVu بترخيص Bitstream Vera/Arev، وFira Sans/Spectral/Lobster/Carlito بترخيص SIL OFL، وعائلة TeX Gyre بترخيص GUST. تشمل الحزمة إشعارات `assets/fonts/*-LICENSE.txt`. قبل إصدار عام اجمع الإشعارات الأصلية، ولا تُعدّل الخطوط المحمية بأسماء محجوزة.

تجنّب ربط محرّك MuPDF أو Ghostscript في هذا التطبيق دون دراسة AGPL أو ترخيص تجاري مستقل؛ لا نحتاجهما الآن.

## مصادر المراجعة

- https://pub.dev/packages/pdfrx/license
- https://pub.dev/packages/dart_pdf_editor/license
- https://pub.dev/packages/dart_pdf_editor_assets/license
- https://pub.dev/packages/dart_pdf_editor_assets (قسم Licences)
- https://pub.dev/packages/file_picker/license
- https://github.com/google/fonts/tree/main/ofl/amiri
- https://pypdf.readthedocs.io/en/stable/meta/faq.html
- https://pikepdf.readthedocs.io/en/latest/topics/license.html
- https://github.com/pdfcpu/pdfcpu/blob/master/LICENSE.txt
- https://github.com/Hopding/pdf-lib/blob/master/LICENSE.md
- https://github.com/mozilla/pdf.js/blob/master/LICENSE
- https://github.com/tesseract-ocr/tesseract/blob/main/LICENSE
