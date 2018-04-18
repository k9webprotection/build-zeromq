@ECHO OFF &SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

SET BUILD_DIR=%~dp0
SET SCRIPT_NAME=%~0

:: Overridable build locations
IF "%DEFAULT_LIBZMQ_DIST%"=="" SET DEFAULT_LIBZMQ_DIST=%BUILD_DIR%\libzmq
IF "%DEFAULT_CPPZMQ_DIST%"=="" SET DEFAULT_CPPZMQ_DIST=%BUILD_DIR%\bindings\cppzmq
IF "%DEFAULT_ZMQCPP_DIST%"=="" SET DEFAULT_ZMQCPP_DIST=%BUILD_DIR%\bindings\zmqcpp
IF "%DEFAULT_AZMQ_DIST%"=="" SET DEFAULT_AZMQ_DIST=%BUILD_DIR%\bindings\azmq
IF "%OBJDIR_ROOT%"=="" SET OBJDIR_ROOT=%BUILD_DIR%\target
IF "%CONFIGS_DIR%"=="" SET CONFIGS_DIR=%BUILD_DIR%\configs

:: Options to control the build
IF "%MSVC_VERSION%"=="" (
    SET MSVC_VERSION_INT=14.1
    SET BUILD_PLATFORM_NAME=windows
) ELSE (
    SET MSVC_VERSION_INT=%MSVC_VERSION%
    SET BUILD_PLATFORM_NAME=windows-msvc-%MSVC_VERSION%
)
IF "%MSVC_VERSION_INT%"=="14.1" (
    SET MSBUILD_EXE=C:\Program Files (x86^)\Microsoft Visual Studio\2017\Professional\MSBuild\15.0\Bin\MSBuild.exe
    SET VSVERSION=vs2017
) ELSE IF "%MSVC_VERSION_INT%"=="14.0" (
    SET MSBUILD_EXE=C:\Program Files (x86^)\MSBuild\14.0\Bin\MSBuild.exe
    SET VSVERSION=vs2015
) ELSE (
    echo Unsupported MSVC version "%MSVC_VERSION_INT%". 1>&2
    echo. 1>&2
    GOTO print_usage
)

:: Options to control the build
IF "%MSVC_BUILD_PARALLEL%"=="" SET MSVC_BUILD_PARALLEL=%NUMBER_OF_PROCESSORS%

:: Include files to copy
SET CPPZMQ_INCLUDE_FILES=zmq.hpp zmq_addon.hpp
SET ZMQCPP_INCLUDE_FILES=include^\zmqcpp.h
SET AZMQ_INCLUDE_DIRS=azmq

:: Calculate the path to the libzmq-dist repository
IF EXIST "%~f1" (
	SET PATH_TO_LIBZMQ_DIST=%~f1
	SHIFT
) ELSE (
	SET PATH_TO_LIBZMQ_DIST=%DEFAULT_LIBZMQ_DIST%
)
IF NOT EXIST "%PATH_TO_LIBZMQ_DIST%\src\libzmq.vers" (
    echo Invalid LibZMQ directory: 1>&2
    echo     "%PATH_TO_LIBZMQ_DIST%" 1>&2
    GOTO print_usage
)

:: Calculate the path to the cppzmq-dist repository
IF EXIST "%~f1" (
	SET PATH_TO_CPPZMQ_DIST=%~f1
	SHIFT
) ELSE (
	SET PATH_TO_CPPZMQ_DIST=%DEFAULT_CPPZMQ_DIST%
)
IF NOT EXIST "%PATH_TO_CPPZMQ_DIST%\zmq.hpp" (
    echo Invalid cppzmq directory: 1>&2
    echo     "%PATH_TO_CPPZMQ_DIST%" 1>&2
    GOTO print_usage
)

:: Calculate the path to the zmqcpp-dist repository
IF EXIST "%~f1" (
    SET PATH_TO_ZMQCPP_DIST=%~f1
    SHIFT
) ELSE (
    SET PATH_TO_ZMQCPP_DIST=%DEFAULT_ZMQCPP_DIST%
)
IF NOT EXIST "%PATH_TO_ZMQCPP_DIST%\include\zmqcpp.h" (
    echo Invalid zmqcpp directory: 1>&2
    echo     "%PATH_TO_ZMQCPP_DIST%" 1>&2
    GOTO print_usage
)

:: Calculate the path to the azmq-dist repository
IF EXIST "%~f1" (
	SET PATH_TO_AZMQ_DIST=%~f1
	SHIFT
) ELSE (
	SET PATH_TO_AZMQ_DIST=%DEFAULT_AZMQ_DIST%
)
IF NOT EXIST "%PATH_TO_AZMQ_DIST%\azmq\socket.hpp" (
    echo Invalid azmq directory: 1>&2
    echo     "%PATH_TO_AZMQ_DIST%" 1>&2
    GOTO print_usage
)


:: Set up the target and the command-line arguments
SET TARGET=%1
SHIFT
:GetArgs
IF "%~1" NEQ "" (
    SET CL_ARGS=%CL_ARGS% %1
    SHIFT
    GOTO GetArgs
)
IF DEFINED CL_ARGS SET CL_ARGS=%CL_ARGS:~1%

:: Call the appropriate function based on target
IF "%TARGET%"=="clean" (
    CALL :do_clean %CL_ARGS% || exit /B 1
) ELSE (
    CALL :do_build %TARGET% %CL_ARGS% || exit /B 1
)
:: Success
exit /B 0


:print_usage
    echo Usage: %SCRIPT_NAME% \path\to\libzmq-dist \paths\to\bindings... ^<arch^|'clean'^> 1>&2
    echo. 1>&2
    echo "\path\to\libzmq-dist" is optional and defaults to: 1>&2
    echo     "%DEFAULT_LIBZMQ_DIST%" 1>&2
    echo "\paths\to\bindings" is one or more optional paths to binding distributions, required are: 1>&2
    echo     "\path\to\cppzmq-dist" is optional and defaults to: 1>&2
    echo         "%DEFAULT_CPPZMQ_DIST%" 1>&2
    echo     "\path\to\zmqcpp-dist" is optional and defaults to: 1>&2
    echo         "%DEFAULT_ZMQCPP_DIST%" 1>&2
    echo     "\path\to\azmq-dist" is optional and defaults to: 1>&2
    echo         "%DEFAULT_AZMQ_DIST%" 1>&2
    echo. 1>&2
    CALL :get_archs
    echo Possible architectures are:
    echo     !ARCHS: =, ! 1>&2
    echo. 1>&2
    echo When specifying clean, you may optionally include an arch to clean, 1>&2
    echo i.e. "%SCRIPT_NAME% clean i386" to clean only the i386 architecture. 1>&2
    echo. 1>&2
@exit /B 1

:get_archs
    @ECHO OFF
    SET ARCHS=
    FOR %%F IN ("%CONFIGS_DIR%\setup-windows.*.bat") DO (
        SET ARCH=%%~nF
        SET ARCHS=!ARCHS! !ARCH:setup-windows.=!
    )
    IF DEFINED ARCHS SET ARCHS=%ARCHS:~1%
@exit /B 0

:do_msbuild_libzmq
    "%MSBUILD_EXE%" builds\msvc\%VSVERSION%\libzmq.sln /t:libzmq:Rebuild ^
                    /p:Configuration=%~1 /p:Platform=%VS_PLATFORM% /m:%MSVC_BUILD_PARALLEL% ^
                    /p:TargetName=%~2 /p:OutDir=%~3\lib\ || exit /B %ERRORLEVEL%
@exit /B 0

:do_build_libzmq
    @ECHO OFF
    SET TARGET=%~1
    SET OUTPUT_ROOT=%~2
    SET BUILD_ROOT=%OUTPUT_ROOT%\build\libzmq

    IF NOT EXIST "%BUILD_ROOT%" (
        echo Creating build directory for %TARGET%...
        mkdir "%BUILD_ROOT%" || exit /B %ERRORLEVEL%
        xcopy /S "%PATH_TO_LIBZMQ_DIST%" "%BUILD_ROOT%" || exit /B %ERRORLEVEL%        
    )

    PUSHD "%BUILD_ROOT%" || exit /B %ERRORLEVEL%
    echo Building architecture "%~1"...
    CALL :do_msbuild_libzmq StaticRelease libzmq "%OUTPUT_ROOT%" || (
        POPD & exit /B 1
    )
    
    echo Building debug architecture "%~1"...
    CALL :do_msbuild_libzmq StaticDebug libzmq-dbg "%OUTPUT_ROOT%" || (
        POPD & exit /B 1
    )
    
    echo Copying include files...
    IF EXIST "%OUTPUT_ROOT%\include" rmdir /Q /S "%OUTPUT_ROOT%\include
    xcopy /I /S "%PATH_TO_LIBZMQ_DIST%\include" "%OUTPUT_ROOT%\include" || (
        POPD & exit /B 1
    )

    POPD & echo Done!    
@exit /B 0

:do_build
    @ECHO OFF
    SET CONFIG_SETUP=%CONFIGS_DIR%\setup-windows.%~1.bat
    
    :: Clean here - in case we pass a "clean" command
    IF "%~2"=="clean" (
        CALL :do_clean %~1
        exit /B %ERRORLEVEL%
    )

    IF EXIST "%CONFIG_SETUP%" (
        :: Load configuration files
        IF EXIST "%CONFIGS_DIR%\setup-windows.bat" (
            CALL "%CONFIGS_DIR%\setup-windows.bat" || exit /B 1
        )
        
        :: Generate the project and build
        CALL "%CONFIG_SETUP%" || exit /B 1
        CALL :do_build_libzmq %~1 "%OBJDIR_ROOT%\objdir-%BUILD_PLATFORM_NAME%.%~1" || exit /B %ERRORLEVEL%
        
        :: Copy the cppzmq include files
        FOR %%h in (%CPPZMQ_INCLUDE_FILES%) DO (
            copy /Y "%PATH_TO_CPPZMQ_DIST%\%%h" "%OBJDIR_ROOT%\objdir-%BUILD_PLATFORM_NAME%.%~1\include" || (
                POPD & exit /B 1
            )
        )
        :: Copy the zmqcpp include files
        FOR %%h in (%ZMQCPP_INCLUDE_FILES%) DO (
            copy /Y "%PATH_TO_ZMQCPP_DIST%\%%h" "%OBJDIR_ROOT%\objdir-%BUILD_PLATFORM_NAME%.%~1\include" || (
                POPD & exit /B 1
            )
        )
        :: Copy the azmq include files
        FOR %%h in (%AZMQ_INCLUDE_DIRS%) DO (
            xcopy /I /S "%PATH_TO_AZMQ_DIST%\%%h" "%OBJDIR_ROOT%\objdir-%BUILD_PLATFORM_NAME%.%~1\include\%%h" || (
                POPD & exit /B 1
            )
        )
    ) ELSE (
        echo Missing/invalid target "%~1" 1>&2
        GOTO print_usage
    )
@exit /B 0

:do_clean
    @ECHO OFF
    IF "%~1"=="" (
        echo Cleaning up all builds in "%OBJDIR_ROOT%"...
        FOR /D %%D IN ("%OBJDIR_ROOT%\objdir-*") DO rmdir /Q /S "%%D" 2>NUL
    ) ELSE (
        echo Cleaning up %~1 builds in "%OBJDIR_ROOT%"...
        rmdir /Q /S "%OBJDIR_ROOT%\objdir-%~1" 2>NUL
        rmdir /Q /S "%OBJDIR_ROOT%\objdir-%BUILD_PLATFORM_NAME%.%~1" 2>NUL
        IF "%~1"=="headers" SET CLEAN_HEADERS=yes
    )

    :: Remove some leftovers
    rmdir /Q "%OBJDIR_ROOT%" 2>NUL
@exit /B 0
