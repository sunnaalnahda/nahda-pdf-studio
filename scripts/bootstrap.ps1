param([switch]$SkipFlutterCreate)
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
flutter test
if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
Write-Host 'Flutter scaffold, dependencies and static checks finished.' -ForegroundColor Green
Write-Host 'Web: flutter run -d chrome'
Write-Host 'APK: flutter build apk --release'
