@echo off
rem Starts VLC in a console with verbose logs (QML errors included),
rem the log is also written to ..\build\vlc-log.txt
setlocal
set VLC=%~dp0..\..\build\vlc\vlc.exe
if not exist "%VLC%" (
    echo VLC is not built yet, run build.bat first.
    pause
    exit /b 1
)
"%VLC%" --qt-redesign -vv --qt-verbose --file-logging --logfile="%~dp0..\..\build\vlc-log.txt" %*
