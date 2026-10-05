@echo off
setlocal
set "setupPowershell=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "setupPowershell=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if "%~1"=="" (
  "%setupPowershell%" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\setup-windows.ps1"
) else (
  "%setupPowershell%" -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0scripts\windows.ps1" -Action Install %*
)
set "result=%errorlevel%"
pause
exit /b %result%
