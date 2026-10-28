@echo off
rem Runs install.ps1 in 64-bit PowerShell, even when started from a 32-bit program.
set PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set PS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
