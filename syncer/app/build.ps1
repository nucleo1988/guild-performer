#Requires -Version 5.1
$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
Set-Location $Root

Write-Host "==> Installing Python deps..."
python -m pip install -r requirements.txt

Write-Host "==> PyInstaller..."
if (Test-Path dist) { Remove-Item -Recurse -Force dist }
if (Test-Path build) { Remove-Item -Recurse -Force build }
python -m PyInstaller --noconfirm GuildPerformerSync.spec
if (-not (Test-Path "dist\GuildPerformerSync.exe")) {
  throw "Build failed: dist\GuildPerformerSync.exe missing"
}
Write-Host "OK: $Root\dist\GuildPerformerSync.exe"

$isccCandidates = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($iscc) {
  Write-Host "==> Inno Setup: $iscc"
  $iss = Join-Path (Split-Path $Root -Parent) "installer\GuildPerformerSync.iss"
  & $iscc $iss
  Write-Host "OK: installer in syncer\dist-installer\"
} else {
  Write-Warning "Inno Setup not found - only portable exe was built."
}

Write-Host "Done."
