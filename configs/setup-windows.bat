@echo off
IF NOT EXIST "%MSBUILD_EXE%" (
    echo MSBuild does not exist at "%MSBUILD_EXE%"> 1&2
    echo. 1>2
    exit /B 1
)

IF "%MIN_WIN_NT_VERSION%"=="" SET MIN_WIN_NT_VERSION=0x0A00

exit /B 0

