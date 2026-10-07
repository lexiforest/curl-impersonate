@echo off
setlocal EnableExtensions

if "%~1"=="" (
  echo Usage: .\win\mingw-build.bat ^<toolchain^> ^<arch^> [MinGW root path] 1>&2
  exit /b 1
)
if "%~2"=="" (
  echo Usage: .\win\mingw-build.bat ^<toolchain^> ^<arch^> [MinGW root path] 1>&2
  exit /b 1
)

if "%~1"=="clang" (
  set "CC=clang"
  set "CXX=clang++"
  if "%~2"=="x86_64" (
    set "ARCH=x86_64"
  ) else if "%~2"=="i686" (
    set "ARCH=i686"
  ) else if "%~2"=="aarch64" (
    set "ARCH=aarch64"
  ) else if "%~2"=="armv7" (
    set "ARCH=armv7"
  ) else (
    echo Unsupported architecture: "%~2" 1>&2
    exit /b 1
  )
) else if "%~1"=="gcc" (
  set "CC=gcc"
  set "CXX=g++"
  if "%~2"=="x86_64" (
    set "ARCH=x86_64"
  ) else if "%~2"=="i686" (
    set "ARCH=i686"
  ) else if "%~2"=="aarch64" (
    set "ARCH=aarch64"
  ) else (
    echo Unsupported architecture: "%~2" 1>&2
    exit /b 1
  )
) else (
  echo Unsupported toolchain: "%~1" 1>&2
  exit /b 1
)

if not "%~3"=="" (
  set "PATH=%~3/bin;%PATH%"
)

if not defined MINGW_CC (
  set "MINGW_CC=%ARCH%-w64-mingw32-%CC%"
)
if not defined MINGW_CXX (
  set "MINGW_CXX=%ARCH%-w64-mingw32-%CXX%"
)

set "BUILD_DIR=%cd%\build"
set "PACKAGES_DIR=%cd%\packages"
set "CONFIGURATION=Release"

if not exist "%PACKAGES_DIR%" mkdir "%PACKAGES_DIR%"

cmake -S . -B "%BUILD_DIR%" -GNinja ^
  -DCMAKE_SYSTEM_NAME="Windows" ^
  -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
  -DCMAKE_INSTALL_PREFIX="%PACKAGES_DIR%" ^
  -DUSE_LIBIDN2=OFF ^
  -DCMAKE_SYSTEM_PROCESSOR="%ARCH%" ^
  -DCMAKE_ASM_NASM_COMPILER="nasm" ^
  -DCMAKE_C_COMPILER="%MINGW_CC%" ^
  -DCMAKE_CXX_COMPILER="%MINGW_CXX%" || exit /b 1

cmake --build "%BUILD_DIR%" --target install-all || exit /b 1

if not exist "%PACKAGES_DIR%\bin" mkdir "%PACKAGES_DIR%\bin"
copy /Y ".\win\bin\*.bat" "%PACKAGES_DIR%\bin\" >NUL || exit /b 1
