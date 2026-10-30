@echo off
rem Builds and runs the engine and host tests with MSVC, the compiler the input method ships with.
setlocal
set IME=%~dp0.
set OUT=%IME%\..\..\dist\windows\imetests
if not exist "%OUT%" mkdir "%OUT%"

for /f "usebackq delims=" %%i in (`"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -products * -property installationPath`) do set VS=%%i
if not defined VS (echo Visual Studio not found & exit /b 1)
call "%VS%\VC\Auxiliary\Build\vcvarsall.bat" amd64 >nul || exit /b 1

cl /nologo /std:c++20 /utf-8 /EHsc /W4 /WX /permissive- /Fo"%OUT%\\" /Fe"%OUT%\tests.exe" ^
    "%IME%\engine\*.cpp" "%IME%\host\*.cpp" "%IME%\tests\FakeClient.cpp" "%IME%\tests\Json.cpp" ^
    "%IME%\tests\EngineTests.cpp" "%IME%\tests\HostTests.cpp" "%IME%\tests\main.cpp" || exit /b 1
"%OUT%\tests.exe" -q "%IME%\..\..\inputmethod" || exit /b 1
