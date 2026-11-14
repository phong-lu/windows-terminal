#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('x64', 'arm64')]
    [string]$Architecture = 'x64',
    [string]$InnoSetupCompiler,
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (!$OutputDirectory) { $OutputDirectory = Join-Path $root 'release-assets' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$makeAppx = & (Join-Path $PSScriptRoot 'Find-WindowsSdkTool.ps1') -Name MakeAppx.exe
$null = & (Join-Path $PSScriptRoot 'Find-WindowsSdkTool.ps1') -Name MakePri.exe

if (!$InnoSetupCompiler) {
    $candidates = @(
        (Join-Path $root '.build-tools/Inno Setup 6/ISCC.exe'),
        (Join-Path $root '.build-tools/InnoSetup/ISCC.exe'),
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )
    $InnoSetupCompiler = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if (!$InnoSetupCompiler -or !(Test-Path -LiteralPath $InnoSetupCompiler)) {
    throw 'Install Inno Setup 6.4.3 or newer, or pass -InnoSetupCompiler with the path to ISCC.exe.'
}
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsRoot = & $vswhere -latest -requires Microsoft.Component.MSBuild Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.Vcpkg -property installationPath
if (!$vsRoot) { throw 'Visual Studio with MSBuild, C++ tools, and vcpkg is required.' }
$msbuild = Join-Path $vsRoot 'MSBuild/Current/Bin/amd64/MSBuild.exe'
$env:VCPKG_ROOT = Join-Path $vsRoot 'VC/vcpkg'
$nuget = Join-Path $root '.build-tools/NuGet.exe'
if (!(Test-Path -LiteralPath $nuget -PathType Leaf)) {
    $command = Get-Command nuget.exe -ErrorAction SilentlyContinue
    if (!$command) { throw 'Place NuGet.exe in .build-tools or add nuget.exe to PATH.' }
    $nuget = $command.Source
}

Push-Location $root
try {
    & $nuget restore build/packages.config -PackagesDirectory packages -NonInteractive
    if ($LASTEXITCODE) { throw 'Build-tool restore failed.' }
    & $nuget restore dep/nuget/packages.config -PackagesDirectory packages -NonInteractive
    if ($LASTEXITCODE) { throw 'Global dependency restore failed.' }
    & $msbuild OpenConsole.slnx /t:Restore /p:Configuration=Release "/p:Platform=$Architecture"
    if ($LASTEXITCODE) { throw 'Dependency restore failed.' }
    & ./build/scripts/Generate-ThirdPartyNotices.ps1 -MarkdownNoticePath ./NOTICE.md -OutputPath ./src/cascadia/CascadiaPackage/NOTICE.html

    $buildStarted = Get-Date
    & $msbuild OpenConsole.slnx /m '/t:Terminal\CascadiaPackage' `
        /p:Configuration=Release "/p:Platform=$Architecture" `
        /p:WindowsTerminalBranding=Release /p:AppxPackageSigningEnabled=false `
        /p:AppxBundle=Never /p:AppxSymbolPackageEnabled=false
    if ($LASTEXITCODE) { throw 'Release build failed.' }

    # MSIX is an intermediate for the existing unpackaged distribution tool.
    # The delivered installer installs the unpackaged application directly.
    $package = Get-ChildItem src/cascadia/CascadiaPackage/AppPackages -Recurse -Filter "CascadiaPackage*_${Architecture}.msix" |
        Where-Object { $_.LastWriteTime -ge $buildStarted } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (!$package) { throw 'The build did not produce a fresh release package.' }
    $xaml = @(Get-ChildItem (Join-Path $package.DirectoryName "Dependencies/$Architecture/Microsoft.UI.Xaml*.appx"))
    if ($xaml.Count -ne 1) { throw 'Expected one matching XAML dependency.' }
    $manifest = [xml](Get-Content src/cascadia/CascadiaPackage/Package.appxmanifest -Raw)
    $version = $manifest.Package.Identity.Version
    $stage = Join-Path $OutputDirectory ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    & ./build/scripts/New-UnpackagedTerminalDistribution.ps1 `
        -TerminalAppX $package.FullName -XamlAppX $xaml[0].FullName -Destination $stage -PortableMode -MakeAppxPath $makeAppx
    $zip = @(Get-ChildItem $stage -Filter '*.zip')
    if ($zip.Count -ne 1) { throw 'Expected one unpackaged distribution ZIP.' }
    Copy-Item -LiteralPath $zip[0].FullName -Destination (Join-Path $OutputDirectory "WindowsTerminal_${version}_${Architecture}-portable.zip")
    $source = Join-Path $stage 'source'
    Expand-Archive -LiteralPath $zip[0].FullName -DestinationPath $source
    $app = Join-Path $source "terminal-$version"
    if (!(Test-Path (Join-Path $app 'WindowsTerminal.exe'))) { throw 'Missing WindowsTerminal.exe.' }
    & $InnoSetupCompiler "/DAppVersion=$version" "/DAppArch=$Architecture" `
        "/DSourceDir=$app" "/DOutputDir=$OutputDirectory" build/scripts/TerminalInstaller.iss
    if ($LASTEXITCODE) { throw 'Installer compilation failed.' }
    $installer = Join-Path $OutputDirectory "WindowsTerminal_${version}_${Architecture}-setup.exe"
    if (!(Test-Path -LiteralPath $installer)) { throw 'Installer was not produced.' }
    Get-Item -LiteralPath $installer
    Get-FileHash -LiteralPath $installer -Algorithm SHA256
}
finally {
    Pop-Location
}
