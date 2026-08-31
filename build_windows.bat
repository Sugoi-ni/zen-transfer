@echo off
echo === Setting up VS Build Tools environment ===
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=amd64
if %ERRORLEVEL% neq 0 (
    echo VsDevCmd failed, trying vcvarsall...
    call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" amd64
)
echo Environment ready.
echo.
echo === Checking tools ===
where cl.exe
where cmake.exe
where ninja.exe
echo.
echo === Running flutter build ===
cd /d C:\zen_transfer_build
flutter build windows --debug 2>&1
echo.
echo === Build exit: %ERRORLEVEL% ===
