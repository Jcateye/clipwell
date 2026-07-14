[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $IdentityName,

    [Parameter(Mandatory = $true)]
    [string] $Publisher,

    [string] $PublisherDisplayName = "Mio Miao Labs LLC.",
    [string] $Version = "1.0.0.0",
    [string] $Runtime = "win-x64",
    [string] $Configuration = "Release"
)

$ErrorActionPreference = "Stop"

function Escape-XmlAttribute([string] $Value) {
    return [System.Security.SecurityElement]::Escape($Value)
}

if ($Version -notmatch '^\d+\.\d+\.\d+\.\d+$') {
    throw "MSIX Version must contain four numeric parts, for example 1.0.0.0."
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent (Split-Path -Parent $projectRoot)
$workRoot = Join-Path $repoRoot "dist/windows-store"
$layoutRoot = Join-Path $workRoot "layout"
$outputRoot = Join-Path $repoRoot "dist"
$outputPath = Join-Path $outputRoot "Clipwell-$Version-$Runtime.msix"

$identityNameXml = Escape-XmlAttribute $IdentityName
$publisherXml = Escape-XmlAttribute $Publisher
$publisherDisplayNameXml = Escape-XmlAttribute $PublisherDisplayName

Remove-Item $workRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item $layoutRoot -ItemType Directory -Force | Out-Null
New-Item $outputRoot -ItemType Directory -Force | Out-Null

dotnet publish (Join-Path $projectRoot "src/Clipwell.Win/Clipwell.Win.csproj") `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    -o $layoutRoot

Copy-Item (Join-Path $PSScriptRoot "Assets") (Join-Path $layoutRoot "Assets") -Recurse -Force

$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<Package
  xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
  xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
  xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
  IgnorableNamespaces="uap rescap">
  <Identity Name="$identityNameXml" Publisher="$publisherXml" Version="$Version" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>Clipwell</DisplayName>
    <PublisherDisplayName>$publisherDisplayNameXml</PublisherDisplayName>
    <Description>A private, local-first clipboard drawer.</Description>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.18362.0" MaxVersionTested="10.0.26100.0" />
  </Dependencies>
  <Resources>
    <Resource Language="en-us" />
  </Resources>
  <Applications>
    <Application Id="Clipwell" Executable="Clipwell.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements
        AppListEntry="default"
        DisplayName="Clipwell"
        Description="A private, local-first clipboard drawer."
        BackgroundColor="transparent"
        Square44x44Logo="Assets\Square44x44Logo.png"
        Square150x150Logo="Assets\Square150x150Logo.png">
        <uap:DefaultTile Wide310x150Logo="Assets\Wide310x150Logo.png" />
      </uap:VisualElements>
    </Application>
  </Applications>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
  </Capabilities>
</Package>
"@

Set-Content -Path (Join-Path $layoutRoot "AppxManifest.xml") -Value $manifest -Encoding utf8

$makeAppx = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\makeappx.exe" |
    Sort-Object FullName -Descending |
    Select-Object -First 1

if (-not $makeAppx) {
    throw "makeappx.exe was not found. Install the Windows 10/11 SDK."
}

Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
& $makeAppx.FullName pack /d $layoutRoot /p $outputPath /o
if ($LASTEXITCODE -ne 0) {
    throw "MakeAppx failed with exit code $LASTEXITCODE."
}

$validationRoot = Join-Path $workRoot "validation"
Remove-Item $validationRoot -Recurse -Force -ErrorAction SilentlyContinue
& $makeAppx.FullName unpack /p $outputPath /d $validationRoot /o | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "MSIX validation unpack failed with exit code $LASTEXITCODE."
}

[xml] $validatedManifest = Get-Content (Join-Path $validationRoot "AppxManifest.xml")
if ($validatedManifest.Package.Identity.Name -ne $IdentityName) {
    throw "Packaged identity does not match the requested Partner Center identity."
}

Write-Output $outputPath
