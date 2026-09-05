# 初始化 Flutter 平台工程并安装依赖
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "未找到 flutter 命令。请先安装 Flutter 并加入 PATH: https://docs.flutter.dev/get-started/install"
}

if (-not (Test-Path "windows")) {
    Write-Host ">> flutter create (windows + android)..."
    flutter create . --org com.origami --project-name imagegen --platforms=windows,android
}

Write-Host ">> flutter pub get..."
flutter pub get

Write-Host ""
Write-Host "完成。运行: flutter run -d windows"
