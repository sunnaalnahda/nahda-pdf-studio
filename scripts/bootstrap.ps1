param([switch]$SkipFlutterCreate, [switch]$RunNativePdfTests)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter غير موجود في PATH. افتح PowerShell من نافذة Flutter SDK أو أضف flutter\bin إلى PATH.'
}

# SIL OFL source: https://github.com/google/fonts/tree/main/ofl/amiri
$fontDir = Join-Path (Get-Location) 'assets\fonts'
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
$fontFile = Join-Path $fontDir 'Amiri-Regular.ttf'
if (-not (Test-Path $fontFile)) {
  $fontUrl = 'https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Regular.ttf'
  Write-Host 'Downloading SIL-OFL Arabic font from Google Fonts...' -ForegroundColor Cyan
  Invoke-WebRequest -Uri $fontUrl -OutFile $fontFile
}
if ((Get-Item $fontFile).Length -lt 100000) { throw 'Font download failed / unexpected file size.' }
$licenseFile = Join-Path $fontDir 'Amiri-OFL.txt'
if (-not (Test-Path $licenseFile)) {
  Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/OFL.txt' -OutFile $licenseFile
}
if ((Get-Item $licenseFile).Length -lt 1000) { throw 'Font licence notice missing or incomplete.' }

if (-not $SkipFlutterCreate) {
  flutter create --platforms=android,web --project-name nahda_pdf_studio --org com.nahda.pdfstudio .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create failed' }
}

# Flutter's default counter test calls MyApp, while this project uses NahdaPdfStudio.
# Remove only the untouched Flutter template test, never a custom test.
$templateTest = Join-Path (Get-Location) 'test\\widget_test.dart'
if (Test-Path -LiteralPath $templateTest) {
  $templateText = Get-Content -LiteralPath $templateTest -Raw
  if ($templateText.Contains('Counter increments smoke test') -and $templateText.Contains('MyApp')) {
    Remove-Item -LiteralPath $templateTest -Force
    Write-Host 'Removed obsolete Flutter-generated counter test.' -ForegroundColor Yellow
  }
}

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }

# Browser tests target the Web runtime and do not require a Windows C/C++ compiler.
# Never use plain 'flutter test' as a default on Windows: pdfium_dart's
# native asset hook requires an MSVC C/C++ toolchain for host-side tests.
Write-Host 'Running Flutter browser smoke tests (Chrome)...' -ForegroundColor Cyan
flutter test -d chrome test/workspace_smoke_test.dart test/pdf_engine_interface_test.dart test/document_workspace_test.dart test/image_info_test.dart test/image_placement_test.dart test/image_tools_dialog_test.dart test/page_fit_zoom_test.dart
if ($LASTEXITCODE -ne 0) {
  throw 'Chrome tests failed. Check Chrome is installed. Native compiler is NOT needed for browser tests.'
}

Write-Host 'Building Flutter Web release...' -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build web failed' }

# Explicitly opt in to native PDF tests on a machine with a C/C++ toolchain.
if ($RunNativePdfTests) {
  Write-Host 'Running native PDF integration test. On Windows this requires MSVC and Windows SDK.' -ForegroundColor Cyan
  flutter test test/arabic_annotation_integration_test.dart test/image_integration_test.dart
  if ($LASTEXITCODE -ne 0) { throw 'Native PDF test failed: check host compiler / native PDF engine.' }
}
Write-Host 'Analysis, browser tests, and Web release build passed.' -ForegroundColor Green
Write-Host 'Web: flutter run -d chrome'
Write-Host 'APK: flutter build apk --release'
Write-Host 'Native PDF test (optional; needs compiler): .\\scripts\\bootstrap.ps1 -SkipFlutterCreate -RunNativePdfTests'
