@echo off
setlocal
set "setupPowershell=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "setupPowershell=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%setupPowershell%" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\setup-windows.ps1" %*
set "result=%errorlevel%"
pause
exit /b %result%
