@echo off
rem Builds kbduzxt.dll for x64, ARM64 and 32-bit apps on 64-bit Windows (wow64), the input method
rem XattotIME.dll for x64, ARM64X and x86, then the installer.
rem Needs Python 3, Visual Studio 2022 with the x64/x86 and ARM64 C++ tools, and Inno Setup 6.
setlocal
set ROOT=%~dp0..
set SRC=%ROOT%\windows\kbd
set GEN=%ROOT%\dist\windows\gen
set DIST=%ROOT%\dist\windows
set IMELIBS=user32.lib advapi32.lib ole32.lib oleaut32.lib uuid.lib

pushd "%ROOT%" && python -m uzkbd.windows.build || exit /b 1
popd

for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do set VS=%%i
if not defined VS (echo Visual Studio not found & exit /b 1)

call :build x64 amd64 "" || exit /b 1
call :build arm64 amd64_arm64 "" || exit /b 1
rem A 32-bit process on 64-bit Windows reads the layout with 64-bit pointers (kbd.h KBD_LONG_POINTER).
call :build wow64 amd64_x86 "/DBUILD_WOW6432" || exit /b 1

call :ime x64 amd64 "" || exit /b 1
call :ime x86 amd64_x86 "" || exit /b 1
rem ARM64X holds ARM64 code for native apps and ARM64EC code for x64 apps under emulation:
rem both share one COM registration on Windows on ARM, so one DLL must load in either.
call :ime arm64\native amd64_arm64 "" || exit /b 1
call :ime arm64\ec amd64_arm64 "/arm64EC" || exit /b 1
call :arm64x || exit /b 1

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

rem Compiles the input method into dist\windows\ime\<dir> and, except for the ARM64 halves, links it.
:ime
setlocal
call "%VS%\VC\Auxiliary\Build\vcvarsall.bat" %2 >nul || exit /b 1
set IME=%ROOT%\windows\ime
set OUT=%DIST%\ime\%1
if not exist "%OUT%" mkdir "%OUT%"
del "%OUT%\*.obj" 2>nul
cl /nologo /c /std:c++20 /utf-8 /EHsc /O2 /MT /W4 /permissive- /DUNICODE /D_UNICODE %~3 /I"%GEN%" ^
    /Fo"%OUT%\\" "%IME%\engine\*.cpp" "%IME%\host\*.cpp" "%IME%\tsf\*.cpp" || exit /b 1
rc /nologo /i "%GEN%" /i "%ROOT%\inputmethod\Resources" /i "%ROOT%\assets" /fo "%OUT%\xattotime.res" "%IME%\tsf\xattotime.rc" || exit /b 1
if /i "%1"=="arm64\native" (endlocal & exit /b 0)
if /i "%1"=="arm64\ec" (endlocal & exit /b 0)
link /nologo /DLL /RELEASE /DEF:"%IME%\tsf\xattotime.def" /OUT:"%OUT%\XattotIME.dll" "%OUT%\*.obj" "%OUT%\xattotime.res" %IMELIBS% || exit /b 1
call :offline "%OUT%\XattotIME.dll" || exit /b 1
echo %OUT%\XattotIME.dll
endlocal & exit /b 0

:arm64x
setlocal
call "%VS%\VC\Auxiliary\Build\vcvarsall.bat" amd64_arm64 >nul || exit /b 1
set IME=%ROOT%\windows\ime
set OUT=%DIST%\ime\arm64
link /nologo /DLL /RELEASE /MACHINE:ARM64X /DEF:"%IME%\tsf\xattotime.def" /DEFARM64NATIVE:"%IME%\tsf\xattotime.def" ^
    /OUT:"%OUT%\XattotIME.dll" "%OUT%\native\*.obj" "%OUT%\ec\*.obj" "%OUT%\native\xattotime.res" %IMELIBS% || exit /b 1
call :offline "%OUT%\XattotIME.dll" || exit /b 1
echo %OUT%\XattotIME.dll
endlocal & exit /b 0

rem The input method reads the word being typed, so it must not be able to send it anywhere.
:offline
dumpbin /nologo /imports %1 | findstr /i /r "ws2_32 wsock32 mswsock wininet winhttp urlmon iphlpapi dnsapi webio httpapi" && (
    echo %~1 links networking code & exit /b 1
)
exit /b 0
