# 构建 ImageGen Setup.exe（Inno Setup，与之前 1.0.0 同款方式）
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Get-AppVersion {
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match '(?m)^version:\s*(\S+)') { return $Matches[1] }
    return "1.0.0"
}

function Find-ISCC {
    @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

$version = Get-AppVersion
Write-Host ">> 版本: $version"

Write-Host ">> Sync Windows app icon ..."
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ">> flutter build windows --release ..."
flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$release = Join-Path $root "build\windows\x64\runner\Release\imagegen.exe"
if (-not (Test-Path $release)) {
    Write-Error "未找到 Release 产物，请先成功编译。"
}

$iscc = Find-ISCC
if (-not $iscc) {
    Write-Error @"
未找到 Inno Setup 6（ISCC.exe）。
请安装: https://jrsoftware.org/isinfo.php
安装后重新运行: .\tool\build_installer.ps1
"@
}

New-Item -ItemType Directory -Force -Path (Join-Path $root "build\installer") | Out-Null

Write-Host ">> Inno Setup: $iscc"
& $iscc "/DMyAppVersion=$version" (Join-Path $PSScriptRoot "installer.iss")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$setup = Join-Path $root "build\installer\ImageGen Setup $version.exe"
Write-Host ""
Write-Host "完成: $setup"
