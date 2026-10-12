@echo off
rem Starts the freshly built VLC with the redesigned interface.
rem Extra arguments are passed to VLC, e.g.  run.bat D:\Videos\movie.mkv
setlocal
set VLC=%~dp0..\..\build\vlc\vlc.exe
if not exist "%VLC%" (
    echo VLC is not built yet, run build.bat first.
    pause
    exit /b 1
)
start "" "%VLC%" --qt-redesign %*
