@echo off
rem Native Windows build of VLC, the result is ..\..\build\vlc\vlc.exe
rem The real script is windows\build.ps1; arguments: -Reconfigure, -Release, -Jobs N
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0windows\build.ps1" %*
if errorlevel 1 (
    echo [build] FAILED, see the output above.
    if "%NOPAUSE%"=="" pause
    exit /b 1
)
if "%NOPAUSE%"=="" pause
