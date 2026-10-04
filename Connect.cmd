@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\windows.ps1" -Action Connect %*
set "result=%errorlevel%"
if not "%result%"=="0" pause
exit /b %result%
