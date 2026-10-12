# Native Windows build of VLC (meson + ninja + WinLibs GCC), no WSL, no MSYS2.
# Run setup.ps1 once before.
#
#   powershell -ExecutionPolicy Bypass -File redesign-dev\windows\build.ps1 [-Reconfigure] [-Clean] [-Release] [-Jobs N]
#     -Reconfigure  rerun meson setup in the existing tree (new contribs, changed meson.build options)
#     -Clean        delete the build tree and configure from scratch
#     -Release      release build instead of debugoptimized
#
# Build tree: <repo>\..\build\win64-native, result: <repo>\..\build\vlc\vlc.exe
param([switch]$Reconfigure, [switch]$Clean, [switch]$Release, [int]$Jobs = 0)
$ErrorActionPreference = 'Stop'

$Repo  = (Resolve-Path "$PSScriptRoot\..\..").Path
$Build = Join-Path (Split-Path $Repo -Parent) 'build'
$Contrib = "$Build\contrib\x86_64-w64-mingw32"
$BuildDir = "$Build\win64-native"
$Out = "$Build\vlc"
if (-not (Test-Path "$Build\native.ini")) { throw 'run redesign-dev\windows\setup.ps1 first' }

# GCC, ninja/meson/pkgconf and the contrib tools (luac, qmake6) first in PATH
$env:PATH = "$Build\toolchain\mingw64\bin;$Build\pyenv\Scripts;$Contrib\bin;$env:PATH"
$env:PKG_CONFIG = "$Build\pyenv\Scripts\pkg-config.exe"
$env:PKG_CONFIG_LIBDIR = "$Contrib\lib\pkgconfig"
$env:PKG_CONFIG_PATH = ''
$Meson = "$Build\pyenv\Scripts\meson.exe"
$BuildType = if ($Release) { 'release' } else { 'debugoptimized' }

function Step($msg) { Write-Host "[build] $msg" -ForegroundColor Cyan }

if ($Clean -and (Test-Path $BuildDir)) {
    Step "removing $BuildDir"
    Remove-Item -Recurse -Force $BuildDir
}
$configured = Test-Path "$BuildDir\build.ninja"
if ($Reconfigure -or -not $configured) {
    $setupArgs = @()
    if ($configured) { $setupArgs += '--reconfigure' }
    Step "configuring ($BuildType)"
    # same options as extras/package/win32/build.sh -m (installers off: they need cygpath/wine)
    & $Meson setup @setupArgs $BuildDir $Repo `
        --native-file "$Build\native.ini" `
        --native-file "$Contrib\share\meson\cross\contrib.ini" `
        --buildtype $BuildType --prefer-static --prefix $Out `
        "-Dcmake_prefix_path=$Contrib" `
        -Dlua=enabled -Dflac=enabled -Dtheoradec=enabled -Dtheoraenc=enabled `
        -Davcodec=enabled -Dmerge-ffmpeg=true -Dlibass=enabled -Dshout=enabled `
        -Dgoom2=enabled -Dsse=enabled -Dzvbi=enabled -Dtelx=disabled `
        -Dqt=enabled -Dskins2=enabled -Dupdate-check=enabled `
        -Dwix=disabled -Dnsis=disabled
    if ($LASTEXITCODE) { throw 'meson setup failed' }
} elseif ($Release) {
    & $Meson configure $BuildDir --buildtype release
    if ($LASTEXITCODE) { throw 'meson configure failed' }
}

Step 'compiling'
$jobArgs = @()
if ($Jobs -gt 0) { $jobArgs += '-j', $Jobs }
& $Meson compile -C $BuildDir @jobArgs
if ($LASTEXITCODE) { throw 'compilation failed' }

Step "installing to $Out"
& $Meson install -C $BuildDir --no-rebuild --quiet
if ($LASTEXITCODE) { throw 'install failed' }

# plugin cache, like the official packages (faster startup)
& "$Out\vlc-cache-gen.exe" "$Out\plugins"
if ($LASTEXITCODE) { throw 'vlc-cache-gen failed' }

Step "done: $Out\vlc.exe"
