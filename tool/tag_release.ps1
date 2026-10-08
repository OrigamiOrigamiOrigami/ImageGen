# Tag current pubspec version and push — GitHub Actions builds & publishes the Release.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Get-AppVersion {
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match '(?m)^version:\s*(\S+)') {
        return ($Matches[1] -split '\+')[0]
    }
    throw "version not found in pubspec.yaml"
}

$version = Get-AppVersion
$tag = "v$version"

if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid version '$version' in pubspec.yaml (expect x.y.z)"
}

$status = git status --porcelain
if ($status) {
    Write-Host "Working tree not clean:"
    git status -sb
    throw "Commit or stash changes before tagging a release."
}

$existing = git tag -l $tag
if ($existing) {
    throw "Tag $tag already exists. Bump version in pubspec.yaml first."
}

Write-Host "Creating tag $tag ..."
git tag $tag
git push origin $tag

Write-Host ""
Write-Host "Pushed $tag. GitHub Actions will build ImageGen-$version.exe and publish the Release."
Write-Host "Watch: https://github.com/OrigamiOrigamiOrigami/ImageGen/actions"
