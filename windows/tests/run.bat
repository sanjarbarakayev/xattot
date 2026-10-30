@echo off
rem Checks the installed layout for this machine's architecture and for 32-bit apps: typetest types
rem every case through ToUnicodeEx, tablecheck reads the DLL's own tables (System32 in a 32-bit
rem process is the wow64 build in SysWOW64). Usage: run.bat <KLID>. Needs the cases.h that
rem uzkbd\windows\build.py writes.
setlocal
set ROOT=%~dp0..\..
set OUT=%ROOT%\dist\windows\typetest
if not exist "%OUT%" mkdir "%OUT%"

for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do set VS=%%i
if not defined VS (echo Visual Studio not found & exit /b 1)

if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" (set NATIVE=arm64) else (set NATIVE=amd64)
call :run %NATIVE% %1 "" || exit /b 1
call :run %NATIVE%_x86 %1 "/DBUILD_WOW6432" || exit /b 1
exit /b 0

:run
setlocal
call "%VS%\VC\Auxiliary\Build\vcvarsall.bat" %1 >nul || exit /b 1
set FLAGS=/nologo /utf-8 /I"%ROOT%\dist\windows\gen" /I"%~dp0."
cl %FLAGS% /W4 /WX /Fo"%OUT%\typetest-%1.obj" /Fe"%OUT%\typetest-%1.exe" "%~dp0typetest.c" user32.lib || exit /b 1
cl %FLAGS% /W3 %~3 /Fo"%OUT%\tablecheck-%1.obj" /Fe"%OUT%\tablecheck-%1.exe" "%~dp0tablecheck.c" || exit /b 1
echo %1:
"%OUT%\typetest-%1.exe" %2 || exit /b 1
"%OUT%\tablecheck-%1.exe" "%SystemRoot%\System32\kbduzxt.dll" || exit /b 1
endlocal & exit /b 0
