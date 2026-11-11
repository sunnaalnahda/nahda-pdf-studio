param([Parameter(Mandatory=$true)][string]$Before,[Parameter(Mandatory=$true)][string]$After)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path '.venv')) {
  py -3.13 -m venv .venv
  if ($LASTEXITCODE -ne 0) { throw 'Install Python 3.13 (or edit this script to use a supported Python).' }
}
& '.\.venv\Scripts\python.exe' -m pip install -r tools\qa\requirements.txt
if ($LASTEXITCODE -ne 0) { throw 'Python dependency installation failed' }
& '.\.venv\Scripts\python.exe' tools\qa\compare_pdf.py --before $Before --after $After --require-incremental --render
exit $LASTEXITCODE
