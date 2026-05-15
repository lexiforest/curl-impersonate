@echo off
setlocal EnableExtensions

set "PATH=%PATH:LLVM=Dummy%"

if "%~1"=="" (
  set "VCVARS_BAT=vcvars64"
) else (
  set "VCVARS_BAT=%~1"
)

if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\%VCVARS_BAT%.bat" (
  call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\%VCVARS_BAT%.bat"
) else (
  call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\%VCVARS_BAT%.bat"
)
if errorlevel 1 exit /b 1

set "BUILD_DIR=%cd%\build"
set "PACKAGES_DIR=%cd%\packages"
set "CONFIGURATION=Release"

if not exist "%PACKAGES_DIR%" mkdir "%PACKAGES_DIR%"

cmake -S . -B "%BUILD_DIR%" -GNinja ^
  -DCMAKE_BUILD_TYPE=%CONFIGURATION% ^
  -DCMAKE_INSTALL_PREFIX="%PACKAGES_DIR%" ^
  -DUSE_LIBIDN2=OFF ^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW ^
  -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded ^
  -DCMAKE_C_COMPILER=clang-cl.exe ^
  -DCMAKE_CXX_COMPILER=clang-cl.exe ^
  -DCMAKE_LINKER=link.exe
if errorlevel 1 exit /b 1

cmake --build "%BUILD_DIR%" --config %CONFIGURATION% --target install-all
if errorlevel 1 exit /b 1

if not exist "%PACKAGES_DIR%\bin" mkdir "%PACKAGES_DIR%\bin"
copy /Y ".\win\bin\*.bat" "%PACKAGES_DIR%\bin\" >NUL
