@echo off
setlocal EnableExtensions

if "%~1"=="" (
  set "TARGET_ENV=x86_64"
) else (
  set "TARGET_ENV=%~1"
)

if /I "%TARGET_ENV%"=="x86_64" set "VCVARS_BAT=vcvars64"
if /I "%TARGET_ENV%"=="i686" set "VCVARS_BAT=vcvars32"
if /I "%TARGET_ENV%"=="arm64" set "VCVARS_BAT=vcvarsarm64"

if defined VCVARS_BAT goto env_ok
echo Unsupported Windows target "%TARGET_ENV%". Expected x86_64, i686, or arm64.
exit /b 1

:env_ok
set "VC_TOOLS_COMPONENT=Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
if /I "%TARGET_ENV%"=="arm64" set "VC_TOOLS_COMPONENT=Microsoft.VisualStudio.Component.VC.Tools.ARM64"

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

set "VCVARS=%VSINSTALLDIR%\VC\Auxiliary\Build\%VCVARS_BAT%.bat"
if not exist "%VCVARS%" (
  echo Could not find %VCVARS_BAT%.bat at "%VCVARS%".
  exit /b 1
)

call "%VCVARS%"
if errorlevel 1 exit /b 1

set "CLANG_CL="
for /f "usebackq tokens=*" %%i in (`where clang-cl.exe 2^>NUL`) do if not defined CLANG_CL set "CLANG_CL=%%i"

if not defined CLANG_CL (
  echo Could not find clang-cl.exe.
  exit /b 1
)

set "LINK_EXE="
for /f "usebackq tokens=*" %%i in (`where link.exe 2^>NUL`) do if not defined LINK_EXE set "LINK_EXE=%%i"

if not defined LINK_EXE (
  echo Could not find link.exe.
  exit /b 1
)

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
  -DCMAKE_C_COMPILER=%CLANG_CL% ^
  -DCMAKE_CXX_COMPILER=%CLANG_CL% ^
  -DCMAKE_LINKER=%LINK_EXE%
if errorlevel 1 exit /b 1

cmake --build "%BUILD_DIR%" --config %CONFIGURATION% --target install-all
if errorlevel 1 exit /b 1

if not exist "%PACKAGES_DIR%\bin" mkdir "%PACKAGES_DIR%\bin"
copy /Y ".\win\bin\*.bat" "%PACKAGES_DIR%\bin\" >NUL
