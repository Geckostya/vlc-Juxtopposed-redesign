@echo off
rem ---------------------------------------------------------------------------
rem  One time setup of the build environment (WSL + Ubuntu 24.04 + mingw-w64).
rem  Run it once, it is safe to run it again.
rem ---------------------------------------------------------------------------
setlocal
set DISTRO=Ubuntu-24.04

wsl --status >nul 2>&1
if errorlevel 1 (
    echo [setup] WSL is not installed, installing it ^(administrator rights needed^)...
    wsl --install --no-distribution
    echo.
    echo [setup] Restart Windows if asked to, then run setup.bat again.
    pause
    exit /b 1
)

wsl -d %DISTRO% -u root -- true >nul 2>&1
if errorlevel 1 (
    echo [setup] Installing %DISTRO% in WSL...
    wsl --install -d %DISTRO% --no-launch
    where ubuntu2404.exe >nul 2>&1 && ubuntu2404.exe install --root
    wsl -d %DISTRO% -u root -- true >nul 2>&1
    if errorlevel 1 (
        echo [setup] Could not start %DISTRO%. Open it once from the Start menu, then run setup.bat again.
        pause
        exit /b 1
    )
)

echo [setup] Installing build dependencies inside %DISTRO%...
wsl -d %DISTRO% -u root --cd "%~dp0." -- bash ./setup-deps.sh
if errorlevel 1 (
    echo [setup] FAILED
    pause
    exit /b 1
)
echo.
echo [setup] Done. Now run build.bat
pause
