[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('MakeAppx.exe', 'MakePri.exe')]
    [string]$Name
)

$roots = @(
    $env:WindowsSdkDir
    foreach ($key in @(
        'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows Kits\Installed Roots'
    )) {
        Get-ItemPropertyValue -Path $key -Name KitsRoot10 -ErrorAction SilentlyContinue
    }
    "${env:ProgramFiles(x86)}\Windows Kits\10"
    "$env:ProgramFiles\Windows Kits\10"
) | Where-Object { $_ } | Select-Object -Unique

$candidates = foreach ($root in $roots) {
    Get-ChildItem -LiteralPath (Join-Path $root 'bin') -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
        ForEach-Object {
            $tool = Join-Path $_.FullName "x64/$Name"
            if (Test-Path -LiteralPath $tool -PathType Leaf) {
                [pscustomobject]@{ Version = [version]$_.Name; Path = $tool }
            }
        }
}
$selected = $candidates | Sort-Object Version -Descending | Select-Object -First 1
if (!$selected) {
    throw "Cannot find $Name in an installed Windows SDK. Install the Windows SDK tools using Visual Studio Installer."
}
$selected.Path
