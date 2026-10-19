@echo off
setlocal EnableExtensions

set "PATH=%PATH:LLVM=Dummy%"

if "%~1"=="" (
  set "VCVARS_BAT=vcvars64"
) else (
  set "VCVARS_BAT=%~1"
)

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requiresAny -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -requires Microsoft.VisualStudio.Component.VC.Tools.ARM64 -property installationPath`) do (
  set "VSINSTALL=%%i"
)

if not defined VSINSTALL (
  echo Visual Studio with C++ tools not found. 1>&2
  exit /b 1
)

call "%VSINSTALL%\VC\Auxiliary\Build\%VCVARS_BAT%.bat" || exit /b 1

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
  -DCMAKE_LINKER=link.exe || exit /b 1

cmake --build "%BUILD_DIR%" --config %CONFIGURATION% --target install-all || exit /b 1

if not exist "%PACKAGES_DIR%\bin" mkdir "%PACKAGES_DIR%\bin"
copy /Y ".\win\bin\*.bat" "%PACKAGES_DIR%\bin\" >NUL || exit /b 1
