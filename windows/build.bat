@echo off
rem Builds kbduzxt.dll for x64, ARM64 and 32-bit apps on 64-bit Windows (wow64), then the installer.
rem Needs Python 3, Visual Studio 2022 with the x64/x86 and ARM64 C++ tools, and Inno Setup 6.
setlocal
set ROOT=%~dp0..
set SRC=%ROOT%\windows\kbd
set GEN=%ROOT%\dist\windows\gen
set DIST=%ROOT%\dist\windows

python "%ROOT%\build_windows.py" || exit /b 1

for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do set VS=%%i
if not defined VS (echo Visual Studio not found & exit /b 1)

call :build x64 amd64 "" || exit /b 1
call :build arm64 amd64_arm64 "" || exit /b 1
rem A 32-bit process on 64-bit Windows reads the layout with 64-bit pointers (kbd.h KBD_LONG_POINTER).
call :build wow64 amd64_x86 "/DBUILD_WOW6432" || exit /b 1

rem Inno Setup 6 packs the DLLs into dist\Xattot-Setup.exe.
set ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe
if not exist "%ISCC%" (echo Inno Setup 6 not found & exit /b 1)
"%ISCC%" /Q "%ROOT%\windows\installer\xattot.iss" || exit /b 1
echo %ROOT%\dist\Xattot-Setup.exe
exit /b 0

:build
setlocal
call "%VS%\VC\Auxiliary\Build\vcvarsall.bat" %2 >nul || exit /b 1
set OUT=%DIST%\%1
if not exist "%OUT%" mkdir "%OUT%"
cl /nologo /c /utf-8 /W3 /O1 /GS- /Zl /I"%GEN%" %~3 /Fo"%OUT%\kbduzxt.obj" "%SRC%\kbduzxt.c" || exit /b 1
rc /nologo /i "%GEN%" /fo "%OUT%\kbduzxt.res" "%SRC%\kbduzxt.rc" || exit /b 1
link /nologo /DLL /NOENTRY /NODEFAULTLIB /RELEASE /SUBSYSTEM:NATIVE /IGNORE:4254 ^
    /MERGE:.edata=.data /MERGE:.rdata=.data /MERGE:.text=.data /MERGE:.bss=.data /SECTION:.data,RE ^
    /DEF:"%SRC%\kbduzxt.def" /OUT:"%OUT%\kbduzxt.dll" "%OUT%\kbduzxt.obj" "%OUT%\kbduzxt.res" || exit /b 1
rem The layout is data: a DLL that imports anything is a build mistake.
dumpbin /nologo /imports "%OUT%\kbduzxt.dll" | findstr /c:"following imports" >nul && (
    echo %1\kbduzxt.dll imports code & exit /b 1
)
del "%OUT%\kbduzxt.obj" "%OUT%\kbduzxt.res" "%OUT%\kbduzxt.exp" "%OUT%\kbduzxt.lib" 2>nul
echo %OUT%\kbduzxt.dll
endlocal & exit /b 0
