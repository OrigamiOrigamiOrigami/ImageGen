# Portable build (no installer)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Get-AppVersion {
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match '(?m)^version:\s*(\S+)') { return $Matches[1] }
    return "1.0.0"
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter not found in PATH"
}

$version = Get-AppVersion
Write-Host "Version: $version"

Write-Host ">> Sync Windows app icon ..."
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ">> flutter build windows --release ..."
flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$release = Join-Path $root "build\windows\x64\runner\Release"
$portableDir = Join-Path $root "build\ImageGen"
$zipPath = Join-Path $root "build\ImageGen-$version-portable.zip"

if (-not (Test-Path (Join-Path $release "imagegen.exe"))) {
    Write-Error "imagegen.exe not found in Release output"
}

Write-Host ">> Copy to build\ImageGen ..."
if (Test-Path $portableDir) { Remove-Item $portableDir -Recurse -Force }
New-Item -ItemType Directory -Path $portableDir | Out-Null
Copy-Item -Path "$release\*" -Destination $portableDir -Recurse -Force

Write-Host ">> Create zip ..."
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$portableDir\*" -DestinationPath $zipPath -CompressionLevel Optimal

$mb = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
Write-Host ""
Write-Host "Portable folder: $portableDir"
Write-Host "Portable zip:    $zipPath ($mb MB)"
Write-Host "Run:             $portableDir\imagegen.exe"
