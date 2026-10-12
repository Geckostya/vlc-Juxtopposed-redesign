# One time setup of the native Windows build environment (no WSL, no MSYS2).
# Everything goes to <repo>\..\build (C:\Projects\VLC\build); safe to run again.
#
#   powershell -ExecutionPolicy Bypass -File redesign-dev\windows\setup.ps1 [-Force]
#
# Installs:
#   build\pyenv       Python venv with meson, ninja, pkgconf, aqtinstall
#   build\toolchain   WinLibs GCC 14.3 (posix threads, msvcrt) = same ABI as the prebuilt contribs
#                     winflexbison (native flex/bison)
#                     Qt 6.8.3 for MinGW (only its host tools are used: moc, rcc, uic, qsb, qmake)
#   build\contrib     prebuilt contribs from the VideoLAN CI (artifacts.videolan.org, "win64" job)
# Needs: Python 3.10+ and git in PATH.
param([switch]$Force)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Repo  = (Resolve-Path "$PSScriptRoot\..\..").Path
$Build = Join-Path (Split-Path $Repo -Parent) 'build'
$Downloads = "$Build\downloads"
$Toolchain = "$Build\toolchain"
New-Item -ItemType Directory -Force $Build, $Downloads, $Toolchain | Out-Null

$GccUrl = 'https://github.com/brechtsanders/winlibs_mingw/releases/download/14.3.0posix-12.0.0-msvcrt-r1/winlibs-x86_64-posix-seh-gcc-14.3.0-mingw-w64msvcrt-12.0.0-r1.zip'
$FlexBisonUrl = 'https://github.com/lexxmark/winflexbison/releases/download/v2.5.25/win_flex_bison-2.5.25.zip'
$QtVersion = '6.8.3'   # must match QTBASE_VERSION in contrib/src/main.mak

function Step($msg) { Write-Host "[setup] $msg" -ForegroundColor Cyan }
function Download($url, $out) {
    if ((Test-Path $out) -and -not $Force) { return }
    Step "downloading $url"
    curl.exe -fL --retry 3 -o "$out.part" $url
    if ($LASTEXITCODE) { throw "download failed: $url" }
    Move-Item -Force "$out.part" $out
}

# 1. Python tools
$Py = "$Build\pyenv\Scripts\python.exe"
if (-not (Test-Path $Py)) {
    Step 'creating Python venv'
    python -m venv "$Build\pyenv"
    if ($LASTEXITCODE) { throw 'python -m venv failed (is Python 3 in PATH?)' }
}
Step 'installing meson, ninja, pkgconf, aqtinstall'
& $Py -m pip install -q --upgrade pip meson ninja pkgconf aqtinstall zstandard
if ($LASTEXITCODE) { throw 'pip install failed' }

# 2. GCC
$Gcc = "$Toolchain\mingw64"
if (-not (Test-Path "$Gcc\bin\gcc.exe") -or $Force) {
    Download $GccUrl "$Downloads\winlibs.zip"
    Step 'extracting GCC'
    if (Test-Path $Gcc) { Remove-Item -Recurse -Force $Gcc }
    & $Py -I -m zipfile -e "$Downloads\winlibs.zip" $Toolchain
    if ($LASTEXITCODE) { throw 'unzip failed' }
}

# 2b. flex + bison (the JSON parser used by the out-of-process preparser needs them)
$FlexBison = "$Toolchain\winflexbison"
if (-not (Test-Path "$FlexBison\win_bison.exe") -or $Force) {
    Download $FlexBisonUrl "$Downloads\winflexbison.zip"
    Step 'extracting flex/bison'
    if (Test-Path $FlexBison) { Remove-Item -Recurse -Force $FlexBison }
    & $Py -I -m zipfile -e "$Downloads\winflexbison.zip" $FlexBison
    if ($LASTEXITCODE) { throw 'unzip failed' }
}

# 3. Qt host tools
$Qt = "$Toolchain\qt\$QtVersion\mingw_64"
if (-not (Test-Path "$Qt\bin\qsb.exe") -or $Force) {
    Step "installing Qt $QtVersion host tools"
    & "$Build\pyenv\Scripts\aqt.exe" install-qt windows desktop $QtVersion win64_mingw -m qtshadertools --outputdir "$Toolchain\qt"
    if ($LASTEXITCODE) { throw 'aqt install failed' }
}

# 4. prebuilt contribs matching the sources (same logic as extras/ci/get-contrib-sha.sh)
$Sha = (git -C $Repo rev-list -1 HEAD -- extras/tools contrib extras/ci extras/package/win32).Trim()
if (-not $Sha) { throw 'cannot compute the contrib SHA with git' }
$Tarball = "$Downloads\vlc-contrib-x86_64-w64-mingw32-$Sha.tar.zst"
$Stamp = "$Build\contrib\.prepared-$Sha"
$PrepArgs = @('--build', $Build, '--gcc', $Gcc, '--qt', $Qt)
if (-not (Test-Path $Stamp) -or $Force) {
    Download "https://artifacts.videolan.org/vlc/win64/vlc-contrib-x86_64-w64-mingw32-$Sha.tar.zst" $Tarball
    Step 'extracting contribs (a few minutes)'
    $PrepArgs += @('--tarball', $Tarball)
}
$env:PATH = "$Build\pyenv\Scripts;$env:PATH"
& $Py -I "$PSScriptRoot\prepare_contrib.py" @PrepArgs
if ($LASTEXITCODE) { throw 'prepare_contrib.py failed' }
New-Item -ItemType File -Force $Stamp | Out-Null

Step 'done, now run redesign-dev\windows\build.ps1'
