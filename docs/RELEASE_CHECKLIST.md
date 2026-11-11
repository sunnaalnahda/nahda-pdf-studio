# Release Gate

- [ ] Flutter `3.47.5` (or explicitly validated later) with Android SDK and Chrome in PATH
- [ ] `scripts/bootstrap.ps1` succeeded (includes downloaded OFL font + notice)
- [ ] `flutter analyze` passes, zero severe warnings
- [ ] `flutter test` passes, particularly `arabic_annotation_integration_test.dart`
- [ ] Open vector_original.pdf on Chrome and on a physical Android device
- [ ] Insert Arabic FreeText and save a different filename on each target
- [ ] Reopen edited PDF in PDFium; validate Arabic shaping and complex diacritics visually
- [ ] Run `scripts/run_quality.ps1` on actual original and saved file
- [ ] Check original bytes prefix and original stream/hash invariants
- [ ] Test file handling: invalid/corrupt PDF, 80MB threshold, cancelled save, storage permission
- [ ] Test signed/encrypted/AcroForm PDFs, reject or warn appropriately
- [ ] Review third-party license notices and transitive dependencies after `flutter pub get`
- [ ] Build web release; serve only over a trusted HTTPS host if published
- [ ] Build signed Android release with developer's own keystore; test upgrade path
- [ ] No customer's private PDF ever committed to GitHub or uploaded to CI
