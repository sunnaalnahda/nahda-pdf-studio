param(
  [ValidateSet('private','public')][string]$Visibility = 'private'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
$repo = 'sunnaalnahda/nahda-pdf-studio'
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Install Git first.' }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'Install GitHub CLI: winget install GitHub.cli' }
gh auth status
if ($LASTEXITCODE -ne 0) { throw 'Sign in first with gh auth login' }
gh repo view $repo --json name 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) { throw "Repository already exists: $repo. Inspect before publishing." }
if (-not (Test-Path '.git')) {
  git init -b main
  if ($LASTEXITCODE -ne 0) { throw 'git init failed' }
}
git add .
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
  git commit -m 'Initial Nahda PDF Studio Flutter and Python QA foundation'
  if ($LASTEXITCODE -ne 0) { throw 'git commit failed; set git config user.name and user.email' }
}
Write-Host "Creating only $repo ($Visibility). Existing repositories are never changed." -ForegroundColor Cyan
if ($Visibility -eq 'public') {
  gh repo create $repo --public --source . --remote origin --push
} else {
  gh repo create $repo --private --source . --remote origin --push
}
if ($LASTEXITCODE -ne 0) { throw 'GitHub repository creation/push failed' }
Write-Host "Published: https://github.com/$repo" -ForegroundColor Green
