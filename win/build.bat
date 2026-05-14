@echo off
setlocal EnableExtensions

set "PATH=%PATH:LLVM=Dummy%"

if "%~1"=="" (
  set "ARCH=x64"
) else (
  set "ARCH=%~1"
)

if /I "%ARCH%"=="x86_64" set "ARCH=x64"
if /I "%ARCH%"=="i686" set "ARCH=x86"

if /I "%ARCH%"=="x64" goto arch_ok
if /I "%ARCH%"=="x86" goto arch_ok
if /I "%ARCH%"=="arm64" goto arch_ok

echo Unsupported MSVC architecture "%ARCH%". Expected x64, x86, or arm64.
exit /b 1

:arch_ok
set "VC_TOOLS_COMPONENT=Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
if /I "%ARCH%"=="arm64" set "VC_TOOLS_COMPONENT=Microsoft.VisualStudio.Component.VC.Tools.ARM64"

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
  echo Could not find vswhere.exe at "%VSWHERE%".
  exit /b 1
)

for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires %VC_TOOLS_COMPONENT% -property installationPath`) do set "VSINSTALLDIR=%%i"
if "%VSINSTALLDIR%"=="" (
  echo Could not find a Visual Studio installation with MSVC tools.
  exit /b 1
)

set "VCVARSALL=%VSINSTALLDIR%\VC\Auxiliary\Build\vcvarsall.bat"
if not exist "%VCVARSALL%" (
  echo Could not find vcvarsall.bat at "%VCVARSALL%".
  exit /b 1
)

call "%VCVARSALL%" %ARCH%
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
