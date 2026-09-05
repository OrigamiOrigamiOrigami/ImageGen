# Build single-file ImageGen.exe (launcher + embedded zip payload)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $root "pubspec.yaml"))) {
    $root = Split-Path -Parent $PSScriptRoot
}
Set-Location $root

function Get-AppVersion {
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match '(?m)^version:\s*(\S+)') { return $Matches[1] }
    return "1.0.0"
}

function Find-VsDevCmd {
    $candidates = @(
        "D:\VisualStudio\Product\VC\Auxiliary\Build\vcvars64.bat",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat",
        "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $install = & $vswhere -latest -property installationPath 2>$null
        if ($install) {
            $vcvars = Join-Path $install "VC\Auxiliary\Build\vcvars64.bat"
            if (Test-Path $vcvars) { return $vcvars }
        }
    }
    return $null
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter not found"
}

$version = Get-AppVersion
Write-Host "Version: $version"

$launcherCpp = Join-Path $PSScriptRoot "launcher\main.cpp"
$launcherRc = Join-Path $PSScriptRoot "launcher\launcher.rc"
$iconIco = Join-Path $root "icon.ico"
if (-not (Test-Path $iconIco)) {
    Write-Error "icon.ico not found at project root"
}

Write-Host ">> Sync Windows app icon ..."
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ">> flutter build windows --release ..."
flutter build windows --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$release = Join-Path $root "build\windows\x64\runner\Release"
if (-not (Test-Path (Join-Path $release "imagegen.exe"))) {
    Write-Error "Release build missing"
}

$work = Join-Path $root "build\single"
$payloadZip = Join-Path $work "payload.zip"
$stubExe = Join-Path $work "launcher_stub.exe"
$outExe = Join-Path $root "build\ImageGen-$version.exe"

Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $work | Out-Null

Write-Host ">> Create payload zip ..."
if (Test-Path $payloadZip) { Remove-Item $payloadZip -Force }
Compress-Archive -Path "$release\*" -DestinationPath $payloadZip -CompressionLevel Optimal

Write-Host ">> Compile launcher stub (with icon) ..."
$vcvars = Find-VsDevCmd
if (-not $vcvars) {
    Write-Error "Visual Studio vcvars64.bat not found (need C++ build tools)"
}

$compileBat = Join-Path $work "compile.bat"
$launcherRes = Join-Path $work "launcher.res"
@"
@echo off
call "$vcvars" >nul
cd /d "$($PSScriptRoot)\launcher"
rc /nologo /fo "$launcherRes" launcher.rc
if errorlevel 1 exit /b 1
cl /nologo /O2 /EHsc /std:c++17 /utf-8 "$launcherCpp" "$launcherRes" /Fe:"$stubExe" user32.lib shell32.lib /link /SUBSYSTEM:WINDOWS /ENTRY:wmainCRTStartup
exit /b %ERRORLEVEL%
"@ | Set-Content -Path $compileBat -Encoding ASCII

cmd /c $compileBat
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if (-not (Test-Path $stubExe)) { Write-Error "launcher compile failed" }

Write-Host ">> Merge stub + payload ..."
$stubBytes = [System.IO.File]::ReadAllBytes($stubExe)
$zipBytes = [System.IO.File]::ReadAllBytes($payloadZip)
$magic = [System.Text.Encoding]::ASCII.GetBytes("IMGPACK1")
$sizeBytes = [System.BitConverter]::GetBytes([uint64]$zipBytes.Length)

$fs = [System.IO.File]::Create($outExe)
try {
    $fs.Write($stubBytes, 0, $stubBytes.Length)
    $fs.Write($zipBytes, 0, $zipBytes.Length)
    $fs.Write($magic, 0, $magic.Length)
    $fs.Write($sizeBytes, 0, $sizeBytes.Length)
} finally {
    $fs.Close()
}

$mb = [math]::Round((Get-Item $outExe).Length / 1MB, 2)
Write-Host ""
Write-Host "Single exe: $outExe ($mb MB)"
Write-Host "First launch extracts to %LOCALAPPDATA%\ImageGen\portable\..."
