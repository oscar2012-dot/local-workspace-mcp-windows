@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\windows.ps1" -Action Verify %*
set "result=%errorlevel%"
pause
exit /b %result%
