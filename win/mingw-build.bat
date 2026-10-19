@echo off
setlocal EnableExtensions DisableDelayedExpansion

if "%~1"=="-h" goto usage
if "%~1"=="--help" goto usage
if "%~1"=="/?" goto usage
if "%~1"=="" goto usage_error
if "%~2"=="" goto usage_error
if not "%~4"=="" goto usage_error

set "TOOLCHAIN=%~1"
set "ARCH=%~2"
if "%TOOLCHAIN%"=="clang" (
  set "CC=clang"
  set "CXX=clang++"
) else if "%TOOLCHAIN%"=="gcc" (
  set "CC=gcc"
  set "CXX=g++"
) else (
  echo Unsupported toolchain: "%TOOLCHAIN%" 1>&2
  exit /b 1
)

if not "%ARCH%"=="x86_64" if not "%ARCH%"=="i686" ^
  if not "%ARCH%"=="aarch64" if not "%ARCH%"=="armv7" (
  echo Unsupported architecture: "%ARCH%" 1>&2
  exit /b 1
)
if "%TOOLCHAIN%:%ARCH%"=="gcc:armv7" (
  echo Unsupported architecture "%ARCH%" for %TOOLCHAIN% 1>&2
  exit /b 1
)

if not "%~3"=="" set "MINGW_ROOT=%~3"
pushd "%~dp0.." || exit /b 1
if defined MINGW_ROOT set "PATH=%MINGW_ROOT%\bin;%PATH%"

if not defined MINGW_CC (
  set "MINGW_CC=%ARCH%-w64-mingw32-%CC%"
)
if not defined MINGW_CXX (
  set "MINGW_CXX=%ARCH%-w64-mingw32-%CXX%"
)

if not defined BUILD_DIR set "BUILD_DIR=%cd%\build\mingw-%TOOLCHAIN%-%ARCH%"
if not defined PACKAGES_DIR set "PACKAGES_DIR=%cd%\packages\mingw-%TOOLCHAIN%-%ARCH%"
set "CONFIGURATION=Release"

cmake -S . -B "%BUILD_DIR%" -GNinja ^
  -DCMAKE_SYSTEM_NAME="Windows" ^
  -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
  -DCMAKE_INSTALL_PREFIX="%PACKAGES_DIR%" ^
  -DUSE_LIBIDN2=OFF ^
  -DCMAKE_SYSTEM_PROCESSOR="%ARCH%" ^
  -DCMAKE_ASM_NASM_COMPILER="nasm" ^
  -DCMAKE_C_COMPILER="%MINGW_CC%" ^
  -DCMAKE_CXX_COMPILER="%MINGW_CXX%" || goto build_failed

cmake --build "%BUILD_DIR%" --target install-all || goto build_failed
popd
exit /b 0

:build_failed
popd
exit /b 1

:usage_error
call :usage 1>&2
exit /b 1

:usage
echo Usage: %~nx0 ^<toolchain^> ^<arch^> [MinGW root path]
echo.
echo Toolchains: clang, gcc
echo Architectures: x86_64, i686, aarch64; armv7 requires clang.
echo.
echo Environment overrides:
echo   MINGW_ROOT    Toolchain directory, overridden by the third argument.
echo   MINGW_CC      C compiler executable.
echo   MINGW_CXX     C++ compiler executable.
echo   BUILD_DIR     Default: build\mingw-^<toolchain^>-^<arch^>.
echo   PACKAGES_DIR  Default: packages\mingw-^<toolchain^>-^<arch^>.
echo.
echo Relative paths are resolved from the repository root.
echo Use -h, --help, or /? to display this help.
exit /b 0
