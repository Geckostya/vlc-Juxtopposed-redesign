# Packs the release build (build.ps1 -Release) into a portable zip for a GitHub release.
#
#   powershell -ExecutionPolicy Bypass -File redesign-dev\windows\package.ps1 -Version 0.1.0
#
# Result: <repo>\..\build\dist\vlc-redesign-<version>-win64.zip (+ .sha256)
#   -Commit <hash>  source commit written to the README (default: HEAD of the repository)
param([Parameter(Mandatory)][string]$Version, [string]$Commit = '')
$ErrorActionPreference = 'Stop'

$Repo  = (Resolve-Path "$PSScriptRoot\..\..").Path
$Build = Join-Path (Split-Path $Repo -Parent) 'build'
$Src = "$Build\vlc-release"
if (-not (Test-Path "$Src\vlc.exe")) { throw 'run build.ps1 -Release first' }

$Name = "vlc-redesign-$Version-win64"
$Dist = "$Build\dist"
$Dir = "$Dist\$Name"
$Zip = "$Dist\$Name.zip"
if (Test-Path $Dir) { Remove-Item -Recurse -Force $Dir }
New-Item -ItemType Directory -Force $Dir | Out-Null

# everything needed at runtime; the SDK (headers, import libraries) is left out
robocopy $Src $Dir /E /XD "$Src\sdk" /XF *.dll.a *.la /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw 'robocopy failed' }
# unzipping changes the file dates, the plugin cache would be stale and only slow the start down
Remove-Item -Force -ErrorAction SilentlyContinue "$Dir\plugins\plugins.dat"

$commit = if ($Commit) { $Commit } else { (git -C $Repo rev-parse --short HEAD).Trim() }
@"
VLC Redesign $Version for Windows (x64)
=======================================

VLC 4.0-dev with the community redesign (Figma "VLC Redesign (Community)").
Built from commit $commit of https://github.com/Geckostya/vlc-Juxtopposed-redesign

Run vlc.exe. No installation needed; delete the folder to remove it.
The classic VLC 4 interface: vlc.exe --no-qt-redesign

Settings are stored in %APPDATA%\vlc, the same place as an installed VLC.

VLC is free software, see COPYING.txt (GPLv2 or later).
"@ | Set-Content -Encoding utf8 "$Dir\README-redesign.txt"

if (Test-Path $Zip) { Remove-Item -Force $Zip }
Compress-Archive -Path $Dir -DestinationPath $Zip -CompressionLevel Optimal
$hash = (Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLower()
"$hash  $Name.zip" | Set-Content -Encoding ascii "$Zip.sha256"

Write-Host "[package] $Zip"
Write-Host "[package] sha256 $hash"
exit 0
