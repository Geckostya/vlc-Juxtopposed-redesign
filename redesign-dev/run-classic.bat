@echo off
rem Starts the freshly built VLC with the classic VLC 4 interface.
setlocal
set VLC=%~dp0..\..\build\vlc\vlc.exe
if not exist "%VLC%" (
    echo VLC is not built yet, run build.bat first.
    pause
    exit /b 1
)
start "" "%VLC%" --no-qt-redesign %*
