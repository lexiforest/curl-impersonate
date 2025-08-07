@echo off

set "PATH=%PATH:LLVM=Dummy%"

IF EXIST "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\%1.bat" (
  call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\%1.bat"
) ELSE (
  call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\%1.bat"
)

:: common dirs
set deps=%cd%\deps
set build=%cd%\build
set packages=%cd%\packages

:: configuration
set configuration=Release

set cmake_common_args=-GNinja -DCMAKE_BUILD_TYPE=%configuration%^
  -DCMAKE_PREFIX_PATH="%packages%" -DCMAKE_INSTALL_PREFIX="%packages%"^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded^
  -DCMAKE_C_COMPILER=clang-cl.exe -DCMAKE_CXX_COMPILER=clang-cl.exe -DCMAKE_LINKER=link.exe

:: Build & Install zlib
pushd "%deps%\zlib"
cmake %cmake_common_args% -S . -B "%build%\zlib"
cmake --build "%build%\zlib" --config %configuration% --target install
move /y "%packages%\lib\zlibstatic.lib" "%packages%\lib\zlib.lib"
popd

:: Build & Install zstd
pushd "%deps%\zstd"
cmake %cmake_common_args% -DZSTD_BUILD_SHARED=OFF -S build\cmake -B "%build%\zstd"
cmake --build "%build%\zstd" --config %configuration% --target install
ren "%packages%\lib\zstd_static.lib" zstd.lib
popd

:: Build & Install brotli
pushd "%deps%\brotli"
cmake %cmake_common_args% -DBUILD_SHARED_LIBS=OFF -S . -B "%build%\brotli"
cmake --build "%build%\brotli" --config %configuration% --target install
popd

:: Build & Install nghttp2
pushd "%deps%\nghttp2"
cmake %cmake_common_args% -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -S . -B "%build%\nghttp2"
cmake --build "%build%\nghttp2" --config %configuration% --target install
popd

:: Build & Install nghttp3
pushd "%deps%\nghttp3"
cmake %cmake_common_args% -DENABLE_SHARED_LIB=OFF -DENABLE_STATIC_LIB=ON -DENABLE_LIB_ONLY=ON -S . -B "%build%\nghttp3"
cmake --build "%build%\nghttp3" --config %configuration% --target install
popd

:: Build & Install boringssl
pushd "%deps%\boringssl"
if "%DISABLE_ASM_ARM64%"=="true" (
  cmake %cmake_common_args% -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DOPENSSL_NO_ASM=ON -S . -B "%build%\boringssl"
) else (
  cmake %cmake_common_args% -DCMAKE_POSITION_INDEPENDENT_CODE=ON -S . -B "%build%\boringssl"
)
cmake --build "%build%\boringssl" --config %configuration% --target install
popd

:: Build & Install ngtcp2
pushd "%deps%\ngtcp2"
cmake %cmake_common_args% -DENABLE_SHARED_LIB=OFF -DENABLE_STATIC_LIB=ON -DENABLE_LIB_ONLY=ON^
  -DENABLE_BORINGSSL=ON -DENABLE_OPENSSL=OFF^
  -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_STANDARD_REQUIRED=ON^
  -DBORINGSSL_INCLUDE_DIR:PATH="%packages:\=/%/include"^
  -DBORINGSSL_LIBRARIES:STRING="%packages:\=/%/lib/ssl.lib;%packages:\=/%/lib/crypto.lib"^
  -S . -B "%build%\ngtcp2"
cmake --build "%build%\ngtcp2" --config %configuration% --target install
popd

:: Build & Install c-ares
pushd "%deps%\c-ares"
cmake %cmake_common_args% -DCARES_SHARED=OFF -DCARES_STATIC=ON -S . -B "%build%\c-ares"
cmake --build "%build%\c-ares" --config %configuration% --target install
popd


:: Build & Install curl
pushd "%deps%\curl"
cmake %cmake_common_args% -DBUILD_SHARED_LIBS=ON^
  -DBUILD_STATIC_LIBS=ON^
  -DBUILD_STATIC_CURL=ON^
  -DCURL_USE_OPENSSL=ON^
  -DCURL_BROTLI=ON^
  -DCURL_ZSTD=ON^
  -DUSE_WIN32_IDN=ON^
  -DUSE_NGHTTP2=ON^
  -DUSE_NGHTTP3=ON^
  -DUSE_NGTCP2=ON^
  -DCURL_USE_LIBPSL=OFF^
  -DHAVE_ECH=1^
  -DUSE_ECH=ON^
  -DUSE_SSLS_EXPORT=ON^
  -DENABLE_IPV6=ON^
  -DENABLE_UNICODE=ON^
  -DENABLE_ARES=ON^
  -DCURL_ENABLE_SSL=ON^
  -DCURL_USE_LIBSSH2=OFF^
  -DOPENSSL_ROOT_DIR="%packages%"^
  "-DCMAKE_C_FLAGS=/DNGHTTP2_STATICLIB=1 /DNGTCP2_STATICLIB=1 /DNGHTTP3_STATICLIB=1 /Dstrtok_r=strtok_s"^
  -S . -B "%build%\curl"
cmake --build "%build%\curl" --config %configuration% --target install
popd

copy .\win\bin\*.bat .\packages\bin /Y
