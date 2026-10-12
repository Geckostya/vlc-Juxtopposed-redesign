@echo off
rem ---------------------------------------------------------------------------
rem  LEGACY: build in WSL. The default is the native build, see ..\build.bat
rem  Builds VLC for Windows x64 in WSL and puts the result in ..\..\..\build\vlc
rem
rem    build.bat            incremental build (first run does everything:
rem                         prebuilt contribs, Qt host tools, configure; 1-2 h)
rem    build.bat --full     redo contribs + bootstrap + configure
rem    build.bat --release  release build
rem ---------------------------------------------------------------------------
setlocal
set DISTRO=Ubuntu-24.04

echo [build] %date% %time%
wsl -d %DISTRO% -u root --cd "%~dp0." -- bash ./build.sh %* 2>&1
if errorlevel 1 (
    echo.
    echo [build] FAILED, see the output above.
    pause
    exit /b 1
)
echo [build] %date% %time%
echo [build] OK. Start VLC with run.bat
if "%NOPAUSE%"=="" pause
