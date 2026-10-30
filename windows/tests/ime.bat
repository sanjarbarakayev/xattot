@echo off
rem Types through the installed input method with imetest in eager and marked mode, as a native app,
rem as a 32-bit app and, on ARM64, as an x64 app under emulation (the ARM64EC half of the DLL).
setlocal
set ROOT=%~dp0..\..
set OUT=%ROOT%\dist\windows\imetest
if not exist "%OUT%" mkdir "%OUT%"

for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do set VS=%%i
if not defined VS (echo Visual Studio not found & exit /b 1)

if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" (set NATIVE=arm64) else (set NATIVE=amd64)
call :run %NATIVE% || exit /b 1
call :run %NATIVE%_x86 || exit /b 1
if "%NATIVE%"=="arm64" (call :run arm64_amd64 || exit /b 1)
exit /b 0

:run
setlocal
call "%VS%\VC\Auxiliary\Build\vcvarsall.bat" %1 >nul || exit /b 1
cl /nologo /std:c++20 /utf-8 /EHsc /W4 /WX /DUNICODE /D_UNICODE /Fo"%OUT%\imetest-%1.obj" /Fe"%OUT%\imetest-%1.exe" ^
    "%~dp0imetest.cpp" ole32.lib user32.lib advapi32.lib || exit /b 1
echo %1:
"%OUT%\imetest-%1.exe" || exit /b 1
"%OUT%\imetest-%1.exe" --marked || exit /b 1
endlocal & exit /b 0
