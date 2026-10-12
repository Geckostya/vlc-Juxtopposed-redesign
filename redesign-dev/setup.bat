@echo off
rem One time setup of the native Windows build environment (no WSL, no MSYS2).
rem The real script is windows\setup.ps1; -Force downloads and unpacks everything again.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\setup.ps1" %*
if errorlevel 1 (
    echo [setup] FAILED, see the output above.
    if "%NOPAUSE%"=="" pause
    exit /b 1
)
if "%NOPAUSE%"=="" pause
