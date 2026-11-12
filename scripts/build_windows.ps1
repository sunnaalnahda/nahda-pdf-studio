param(
  [switch]$Release,
  [switch]$RunNativeTest
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter was not found in PATH. Open a shell with Flutter configured.'
}

# flutter doctor checks MSVC, CMake, and SDK, but it does NOT check ATL.
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) {
  throw 'Visual Studio Installer (vswhere.exe) was not found. Install Desktop development with C++.'
}
$installations = @(& $vswhere -latest -products '*' -property installationPath)
if ($installations.Count -eq 0 -or [string]::IsNullOrWhiteSpace($installations[0])) {
  throw 'A usable Visual Studio installation was not found.'
}
$selectedVs = $installations[0].Trim()
$atlPattern = Join-Path $selectedVs 'VC\Tools\MSVC\*\atlmfc\include\atlstr.h'
$atl = @(Get-Item -Path $atlPattern -ErrorAction SilentlyContinue)
if ($atl.Count -eq 0) {
  throw "Missing ATL header atlstr.h under $selectedVs. Open Visual Studio Installer > Modify > Individual components > C++ ATL for the installed MSVC toolset."
}
Write-Host "ATL located: $($atl[0].FullName)" -ForegroundColor Green

$fontDir = Join-Path (Get-Location) 'assets\fonts'
New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
$fontFile = Join-Path $fontDir 'Amiri-Regular.ttf'
$licenseFile = Join-Path $fontDir 'Amiri-OFL.txt'
if (-not (Test-Path -LiteralPath $fontFile)) {
  Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/Amiri-Regular.ttf' -OutFile $fontFile
}
if (-not (Test-Path -LiteralPath $licenseFile)) {
  Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/google/fonts/main/ofl/amiri/OFL.txt' -OutFile $licenseFile
}
if ((Get-Item $fontFile).Length -lt 100000) { throw 'Arabic font was not downloaded correctly.' }

if (-not (Test-Path -LiteralPath 'windows\CMakeLists.txt')) {
  Write-Host 'Creating Windows runner without replacing existing platform sources...' -ForegroundColor Cyan
  flutter create --platforms=windows --project-name nahda_pdf_studio --org com.nahda.pdfstudio .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create for Windows failed' }
}

# Remove only Flutter's unmodified counter template; never remove custom tests.
$templateTest = Join-Path (Get-Location) 'test\widget_test.dart'
if (Test-Path -LiteralPath $templateTest) {
  $source = Get-Content -LiteralPath $templateTest -Raw
  if ($source.Contains('Counter increments smoke test') -and $source.Contains('MyApp')) {
    Remove-Item -LiteralPath $templateTest -Force
    Write-Host 'Removed obsolete Flutter counter test.' -ForegroundColor Yellow
  }
}

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
flutter analyze
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }

if ($RunNativeTest) {
  flutter test test/arabic_annotation_integration_test.dart test/page_tools_integration_test.dart test/document_workspace_native_test.dart --reporter expanded
  if ($LASTEXITCODE -ne 0) { throw 'Native PDF integration test failed on Windows' }
}

if ($Release) {
  flutter build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'Windows Release build failed' }
  Write-Host 'Release files: build\windows\x64\runner\Release (distribute the entire folder).' -ForegroundColor Green
} else {
  flutter run -d windows
  if ($LASTEXITCODE -ne 0) { throw 'Windows debug run failed' }
}
