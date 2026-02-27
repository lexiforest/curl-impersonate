cmake_minimum_required(VERSION 3.20)
if(POLICY CMP0135)
  cmake_policy(SET CMP0135 NEW)
endif()

project(curl_impersonate_superbuild LANGUAGES C CXX)

include(ExternalProject)
include(GNUInstallDirs)
include(ProcessorCount)

find_program(_gmake_exe gmake)
if(_gmake_exe)
  set(AUTOTOOLS_MAKE "${_gmake_exe}")
else()
  set(AUTOTOOLS_MAKE "make")
endif()

ProcessorCount(_nproc)
if(NOT _nproc)
  set(_nproc 4)
endif()
set(SUBJOBS "${_nproc}" CACHE STRING "Parallel build jobs")

# Versions and URLs
set(BROTLI_VERSION "1.2.0")
# Chrome 135.0.7049.41
# In case this is changed, update build-and-test-make.yml and build-win as well
set(BORING_SSL_COMMIT "673e61fc215b178a90c0e67858bbf162c8158993")
# We need to pin to 1.64 or lower, since the priority flag was removed.
# See: https://nghttp2.org/blog/2025/03/02/nghttp2-v1-65-0/
set(NGHTTP2_VERSION "1.63.0")
set(NGTCP2_VERSION "1.20.0")
set(NGHTTP3_VERSION "1.15.0")
set(ZLIB_VERSION "1.3.1")
set(ZSTD_VERSION "1.5.7")
set(LIBUNISTRING_VERSION "1.1")
set(LIBIDN2_VERSION "2.3.7")
set(CURL_VERSION "curl-8_15_0")

set(ZLIB_URL "https://github.com/madler/zlib/releases/download/v${ZLIB_VERSION}/zlib-${ZLIB_VERSION}.tar.gz")
set(ZSTD_URL "https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz")
set(BROTLI_URL "https://github.com/google/brotli/archive/refs/tags/v${BROTLI_VERSION}.tar.gz")
set(BORINGSSL_URL "https://github.com/google/boringssl/archive/${BORING_SSL_COMMIT}.zip")
set(NGHTTP2_URL "https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/nghttp2-${NGHTTP2_VERSION}.tar.bz2")
set(NGTCP2_URL "https://github.com/ngtcp2/ngtcp2/releases/download/v${NGTCP2_VERSION}/ngtcp2-${NGTCP2_VERSION}.tar.bz2")
set(NGHTTP3_URL "https://github.com/ngtcp2/nghttp3/releases/download/v${NGHTTP3_VERSION}/nghttp3-${NGHTTP3_VERSION}.tar.bz2")
set(LIBUNISTRING_URL "https://ftp.gnu.org/gnu/libunistring/libunistring-${LIBUNISTRING_VERSION}.tar.gz")
set(LIBIDN2_URL "https://ftp.gnu.org/gnu/libidn/libidn2-${LIBIDN2_VERSION}.tar.gz")
set(CURL_URL "https://github.com/curl/curl/archive/${CURL_VERSION}.tar.gz")

set(_disable_boringssl_asm_default OFF)
if(WIN32)
  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _ci_system_processor_lc)
  string(TOLOWER "${CMAKE_C_COMPILER_TARGET}" _ci_c_target_lc)
  string(TOLOWER "${CMAKE_CXX_COMPILER_TARGET}" _ci_cxx_target_lc)
  string(TOLOWER "${CMAKE_GENERATOR_PLATFORM}" _ci_generator_platform_lc)
  if(_ci_system_processor_lc MATCHES "arm64|aarch64"
      OR _ci_c_target_lc MATCHES "arm64|aarch64"
      OR _ci_cxx_target_lc MATCHES "arm64|aarch64"
      OR _ci_generator_platform_lc MATCHES "arm64")
    set(_disable_boringssl_asm_default ON)
  endif()
endif()
option(DISABLE_BORINGSSL_ASM "Disable BoringSSL asm (arm64 workaround)" ${_disable_boringssl_asm_default})
if(WIN32 OR APPLE OR ANDROID)
  set(_use_libidn2_default OFF)
else()
  set(_use_libidn2_default ON)
endif()
option(USE_LIBIDN2 "Build and use libidn2/libunistring for IDN support" ${_use_libidn2_default})
set(CURL_CA_BUNDLE "" CACHE STRING "CA bundle for curl ('auto', 'none', or full path)")
set(CURL_CA_PATH "" CACHE STRING "CA directory for curl ('auto', 'none', or full path)")

set(DEPS_SRC_DIR "${CMAKE_BINARY_DIR}/deps/src")
set(DEPS_BUILD_DIR "${CMAKE_BINARY_DIR}/deps/build")
set(DEPS_INSTALL_DIR "${CMAKE_BINARY_DIR}/deps/install")

if(WIN32)
  find_program(PATCH_EXE patch
    HINTS
      "$ENV{ProgramFiles}/Git/usr/bin"
      "$ENV{ProgramW6432}/Git/usr/bin"
      "C:/Program Files/Git/usr/bin"
      "C:/Program Files (x86)/Git/usr/bin"
  )
else()
  find_program(PATCH_EXE NAMES gpatch patch)
endif()
if(NOT PATCH_EXE)
  set(PATCH_EXE patch)
endif()

set(_common_cmake_args
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_LIBDIR=lib
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
)

# Avoid include shadowing from system/local prefixes when building deps:
# force CMake "SYSTEM" include dirs to be passed as -I, and avoid imported
# targets being marked as system includes.
set(_shadow_avoid_cmake_args
  -DCMAKE_NO_SYSTEM_FROM_IMPORTED=ON
  -DCMAKE_INCLUDE_SYSTEM_FLAG_C=-I
)

if(CMAKE_C_COMPILER)
  list(APPEND _common_cmake_args -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER})
endif()
if(CMAKE_CXX_COMPILER)
  list(APPEND _common_cmake_args -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER})
endif()
if(CMAKE_SYSTEM_NAME)
  list(APPEND _common_cmake_args -DCMAKE_SYSTEM_NAME=${CMAKE_SYSTEM_NAME})
endif()
if(CMAKE_SYSTEM_PROCESSOR)
  list(APPEND _common_cmake_args -DCMAKE_SYSTEM_PROCESSOR=${CMAKE_SYSTEM_PROCESSOR})
endif()
if(CMAKE_OSX_SYSROOT)
  list(APPEND _common_cmake_args -DCMAKE_OSX_SYSROOT=${CMAKE_OSX_SYSROOT})
endif()
if(CMAKE_OSX_DEPLOYMENT_TARGET)
  list(APPEND _common_cmake_args -DCMAKE_OSX_DEPLOYMENT_TARGET=${CMAKE_OSX_DEPLOYMENT_TARGET})
endif()
if(CMAKE_MSVC_RUNTIME_LIBRARY)
  list(APPEND _common_cmake_args -DCMAKE_MSVC_RUNTIME_LIBRARY=${CMAKE_MSVC_RUNTIME_LIBRARY})
endif()
if(CMAKE_LINKER)
  list(APPEND _common_cmake_args -DCMAKE_LINKER=${CMAKE_LINKER})
endif()

list(JOIN _common_cmake_args " " _common_cmake_args_str)

# zlib
ExternalProject_Add(zlib
  URL "${ZLIB_URL}"
  SOURCE_DIR "${DEPS_SRC_DIR}/zlib"
  BINARY_DIR "${DEPS_BUILD_DIR}/zlib"
  INSTALL_DIR "${DEPS_INSTALL_DIR}"
  CMAKE_ARGS
    ${_common_cmake_args}
    -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    -DBUILD_SHARED_LIBS=OFF
    -DZLIB_BUILD_EXAMPLES=OFF
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --parallel ${SUBJOBS}
)

# zstd
ExternalProject_Add(zstd
  URL "${ZSTD_URL}"
  SOURCE_DIR "${DEPS_SRC_DIR}/zstd"
  BINARY_DIR "${DEPS_BUILD_DIR}/zstd"
  INSTALL_DIR "${DEPS_INSTALL_DIR}"
  SOURCE_SUBDIR build/cmake
  CMAKE_ARGS
    ${_common_cmake_args}
    -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    -DZSTD_BUILD_SHARED=OFF
    -DZSTD_BUILD_STATIC=ON
    -DZSTD_BUILD_PROGRAMS=OFF
    -DZSTD_BUILD_CONTRIB=OFF
    -DZSTD_BUILD_TESTS=OFF
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --parallel ${SUBJOBS}
)

# brotli
ExternalProject_Add(brotli
  URL "${BROTLI_URL}"
  SOURCE_DIR "${DEPS_SRC_DIR}/brotli"
  BINARY_DIR "${DEPS_BUILD_DIR}/brotli"
  INSTALL_DIR "${DEPS_INSTALL_DIR}"
  PATCH_COMMAND ${PATCH_EXE} -p1 -i "${CMAKE_SOURCE_DIR}/patches/brotli.patch"
  CMAKE_ARGS
    ${_common_cmake_args}
    -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    -DBUILD_SHARED_LIBS=OFF
    -DBROTLI_DISABLE_TESTS=ON
    -DBROTLI_DISABLE_TOOLS=ON
    -DBROTLI_BUILD_TOOLS=OFF
    -DCMAKE_MACOSX_BUNDLE=OFF
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --parallel ${SUBJOBS}
  INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target install --parallel ${SUBJOBS}
)

# boringssl

# The extra CMAKE_C_FLAGS are needed because otherwise boringssl fails to
# compile in release mode on some systems with gcc 12 (e.g. Fedora).
# In addition, guard these options with -Wno-unknown-warning-option to
# prevent clang from failing on them.
set(_boringssl_c_flags "${CMAKE_C_FLAGS}")
string(APPEND _boringssl_c_flags " -Wno-unknown-warning-option -Wno-stringop-overflow -Wno-array-bounds -Wno-macro-redefined")
set(_boringssl_cxx_flags "${CMAKE_CXX_FLAGS}")
string(APPEND _boringssl_cxx_flags " -Wno-macro-redefined")

set(_boringssl_cmake_args
  ${_common_cmake_args}
  "-DCMAKE_C_FLAGS=${_boringssl_c_flags}"
  "-DCMAKE_CXX_FLAGS=${_boringssl_cxx_flags}"
)
if(DISABLE_BORINGSSL_ASM)
  list(APPEND _boringssl_cmake_args -DOPENSSL_NO_ASM=ON)
endif()

ExternalProject_Add(boringssl
  URL "${BORINGSSL_URL}"
  SOURCE_DIR "${DEPS_SRC_DIR}/boringssl"
  BINARY_DIR "${DEPS_BUILD_DIR}/boringssl"
  PATCH_COMMAND ${PATCH_EXE} -p1 -i "${CMAKE_SOURCE_DIR}/patches/boringssl.patch"
  CMAKE_ARGS ${_boringssl_cmake_args}
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target ssl crypto --parallel ${SUBJOBS}
  INSTALL_COMMAND ""
)

ExternalProject_Get_Property(boringssl source_dir binary_dir)
set(BORINGSSL_SRC_DIR "${source_dir}")
set(BORINGSSL_BIN_DIR "${binary_dir}")
if(WIN32)
  set(BORINGSSL_SSL_LIB "${BORINGSSL_BIN_DIR}/ssl/ssl.lib")
  set(BORINGSSL_CRYPTO_LIB "${BORINGSSL_BIN_DIR}/crypto/crypto.lib")
else()
  set(BORINGSSL_SSL_LIB "${BORINGSSL_BIN_DIR}/ssl/libssl.a")
  set(BORINGSSL_CRYPTO_LIB "${BORINGSSL_BIN_DIR}/crypto/libcrypto.a")
endif()

set(_ngtcp2_boringssl_libs_arg)
if(WIN32)
  list(APPEND _ngtcp2_boringssl_libs_arg "-DBORINGSSL_LIBRARIES=${BORINGSSL_SSL_LIB};${BORINGSSL_CRYPTO_LIB}")
endif()

# nghttp2
ExternalProject_Add(nghttp2
  URL "${NGHTTP2_URL}"
  SOURCE_DIR "${DEPS_SRC_DIR}/nghttp2"
  BINARY_DIR "${DEPS_BUILD_DIR}/nghttp2"
  INSTALL_DIR "${DEPS_INSTALL_DIR}"
  CMAKE_ARGS
    ${_common_cmake_args}
    ${_shadow_avoid_cmake_args}
    -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    -DCMAKE_DISABLE_FIND_PACKAGE_Libnghttp3=ON
    -DENABLE_LIB_ONLY=ON
    -DBUILD_SHARED_LIBS=OFF
    -DBUILD_STATIC_LIBS=ON
    -DENABLE_DOC=OFF
    -DBUILD_TESTING=OFF
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --parallel ${SUBJOBS}
  INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target install --parallel ${SUBJOBS}
)

# nghttp3
ExternalProject_Add(nghttp3
  URL "${NGHTTP3_URL}"
  SOURCE_DIR "${DEPS_SRC_DIR}/nghttp3"
  BINARY_DIR "${DEPS_BUILD_DIR}/nghttp3"
  INSTALL_DIR "${DEPS_INSTALL_DIR}"
  PATCH_COMMAND ${PATCH_EXE} -p1 -i "${CMAKE_SOURCE_DIR}/patches/nghttp3.patch"
  CMAKE_ARGS
    ${_common_cmake_args}
    ${_shadow_avoid_cmake_args}
    -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    -DENABLE_LIB_ONLY=ON
    -DENABLE_SHARED_LIB=OFF
    -DENABLE_STATIC_LIB=ON
    -DBUILD_TESTING=OFF
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --parallel ${SUBJOBS}
  INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target install --parallel ${SUBJOBS}
)

# ngtcp2
ExternalProject_Add(ngtcp2
  URL "${NGTCP2_URL}"
  SOURCE_DIR "${DEPS_SRC_DIR}/ngtcp2"
  BINARY_DIR "${DEPS_BUILD_DIR}/ngtcp2"
  INSTALL_DIR "${DEPS_INSTALL_DIR}"
  PATCH_COMMAND ${PATCH_EXE} -p1 -i "${CMAKE_SOURCE_DIR}/patches/ngtcp2.patch"
  DEPENDS boringssl
  CMAKE_ARGS
    ${_common_cmake_args}
    ${_shadow_avoid_cmake_args}
    -DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>
    -DENABLE_SHARED_LIB=OFF
    -DENABLE_STATIC_LIB=ON
    -DENABLE_LIB_ONLY=ON
    -DENABLE_OPENSSL=OFF
    -DENABLE_BORINGSSL=ON
    -DENABLE_PICOTLS=OFF
    -DENABLE_WOLFSSL=OFF
    -DENABLE_GNUTLS=OFF
    -DBUILD_TESTING=OFF
    -DBORINGSSL_INCLUDE_DIR=${BORINGSSL_SRC_DIR}/include
    ${_ngtcp2_boringssl_libs_arg}
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --parallel ${SUBJOBS}
  INSTALL_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --target install --parallel ${SUBJOBS}
)

if(USE_LIBIDN2)
  # We are using `true` command to bypass most of the docs generation stuff.

  # libunistring
  ExternalProject_Add(libunistring
    URL "${LIBUNISTRING_URL}"
    SOURCE_DIR "${DEPS_SRC_DIR}/libunistring"
    BINARY_DIR "${DEPS_BUILD_DIR}/libunistring"
    INSTALL_DIR "${DEPS_INSTALL_DIR}"
    DOWNLOAD_EXTRACT_TIMESTAMP FALSE
    CONFIGURE_COMMAND
      ${CMAKE_COMMAND} -E env
        ACLOCAL=true AUTOCONF=true AUTOHEADER=true AUTOMAKE=true MAKEINFO=true
        <SOURCE_DIR>/configure --prefix=<INSTALL_DIR> --disable-shared --enable-static --with-pic --disable-maintainer-mode
    BUILD_COMMAND ${CMAKE_COMMAND} -E env MAKEINFO=true ${AUTOTOOLS_MAKE} -j${SUBJOBS}
    INSTALL_COMMAND ${CMAKE_COMMAND} -E env MAKEINFO=true ${AUTOTOOLS_MAKE} install
  )

  # libidn2
  # Keep external libunistring, but force LTLIBUNISTRING to the installed
  # .la path so libtool does not resolve -lunistring to libidn2's own
  # in-progress unistring/.libs output archive.
  ExternalProject_Add(libidn2
    URL "${LIBIDN2_URL}"
    SOURCE_DIR "${DEPS_SRC_DIR}/libidn2"
    BINARY_DIR "${DEPS_BUILD_DIR}/libidn2"
    INSTALL_DIR "${DEPS_INSTALL_DIR}"
    DEPENDS libunistring
    DOWNLOAD_EXTRACT_TIMESTAMP FALSE
    CONFIGURE_COMMAND
      ${CMAKE_COMMAND} -E env
        PKG_CONFIG_PATH=${DEPS_INSTALL_DIR}/lib/pkgconfig
        ACLOCAL=true AUTOCONF=true AUTOHEADER=true AUTOMAKE=true MAKEINFO=true HELP2MAN=true
        <SOURCE_DIR>/configure --prefix=<INSTALL_DIR> --disable-shared --enable-static --with-pic --disable-nls --disable-maintainer-mode --with-libunistring-prefix=${DEPS_INSTALL_DIR}
    BUILD_COMMAND ${CMAKE_COMMAND} -E env MAKEINFO=true ${AUTOTOOLS_MAKE} LTLIBUNISTRING=${DEPS_INSTALL_DIR}/lib/libunistring.la HELP2MAN=true -j${SUBJOBS}
    INSTALL_COMMAND ${CMAKE_COMMAND} -E env MAKEINFO=true ${AUTOTOOLS_MAKE} LTLIBUNISTRING=${DEPS_INSTALL_DIR}/lib/libunistring.la HELP2MAN=true install
  )
endif()

# curl
set(_curl_prefix_path "${DEPS_INSTALL_DIR}")
if(WIN32)
  set(_curl_pkg_path_sep ";")
  set(_curl_use_pkgconfig_flag -DCURL_USE_PKGCONFIG=OFF)
  set(_curl_configure_env)
else()
  set(_curl_pkg_path_sep ":")
  set(_curl_use_pkgconfig_flag -DCURL_USE_PKGCONFIG=ON)
  set(_curl_configure_env
    PKG_CONFIG_PATH=${DEPS_INSTALL_DIR}/lib/pkgconfig${_curl_pkg_path_sep}${DEPS_INSTALL_DIR}/share/pkgconfig
    PKG_CONFIG_LIBDIR=${DEPS_INSTALL_DIR}/lib/pkgconfig${_curl_pkg_path_sep}${DEPS_INSTALL_DIR}/share/pkgconfig
  )
endif()

if(WIN32)
  set(_curl_idn_flags -DUSE_WIN32_IDN=ON -DUSE_LIBIDN2=OFF)
elseif(APPLE)
  if(USE_LIBIDN2)
    set(_curl_idn_flags -DUSE_APPLE_IDN=OFF -DUSE_LIBIDN2=ON)
  else()
    set(_curl_idn_flags -DUSE_APPLE_IDN=ON -DUSE_LIBIDN2=OFF)
  endif()
elseif(ANDROID)
  set(_curl_idn_flags -DUSE_LIBIDN2=OFF)
elseif(USE_LIBIDN2)
  set(_curl_idn_flags -DUSE_LIBIDN2=ON)
else()
  set(_curl_idn_flags -DUSE_LIBIDN2=OFF)
endif()

# Single curl build mode: produce shared+static libcurl and static curl binary.
set(_curl_build_flags
  -DBUILD_SHARED_LIBS=ON
  -DBUILD_STATIC_LIBS=ON
  -DBUILD_STATIC_CURL=ON
)

set(_curl_ca_flags)
if(NOT CURL_CA_BUNDLE STREQUAL "")
  list(APPEND _curl_ca_flags "-DCURL_CA_BUNDLE=${CURL_CA_BUNDLE}")
endif()
if(NOT CURL_CA_PATH STREQUAL "")
  list(APPEND _curl_ca_flags "-DCURL_CA_PATH=${CURL_CA_PATH}")
endif()

set(_curl_deps zlib zstd brotli boringssl nghttp2 ngtcp2 nghttp3)
if(USE_LIBIDN2)
  list(APPEND _curl_deps libidn2)
endif()

if(WIN32)
  set(_curl_zlib_library "${DEPS_INSTALL_DIR}/lib/zlibstatic.lib")
else()
  set(_curl_zlib_library "${DEPS_INSTALL_DIR}/lib/libz.a")
endif()

set(_curl_platform_flags)
if(WIN32)
  set(_curl_platform_c_flags "${CMAKE_C_FLAGS}")
  string(APPEND _curl_platform_c_flags " /DNGHTTP2_STATICLIB=1 /DNGTCP2_STATICLIB=1 /DNGHTTP3_STATICLIB=1 /Dstrtok_r=strtok_s")
  list(APPEND _curl_platform_flags "-DCMAKE_C_FLAGS=${_curl_platform_c_flags}")
  list(APPEND _curl_platform_flags -DENABLE_UNICODE=ON)
endif()
if(CMAKE_MSVC_RUNTIME_LIBRARY)
  list(APPEND _curl_platform_flags "-DCMAKE_MSVC_RUNTIME_LIBRARY=${CMAKE_MSVC_RUNTIME_LIBRARY}")
endif()
if(NOT WIN32)
  # Static BoringSSL/AWS-LC are C++ archives. curl's configure-time symbol
  # probes are C-link checks and can fail unless C++ runtime libs are explicit.
  set(_curl_cxx_link_libs)
  foreach(_lib IN LISTS CMAKE_CXX_IMPLICIT_LINK_LIBRARIES)
    if(_lib STREQUAL "stdc++" OR _lib STREQUAL "c++" OR _lib STREQUAL "c++abi")
      list(APPEND _curl_cxx_link_libs "${_lib}")
    endif()
  endforeach()
  if(NOT _curl_cxx_link_libs)
    if(APPLE OR BSD OR ANDROID)
      list(APPEND _curl_cxx_link_libs "c++")
    else()
      list(APPEND _curl_cxx_link_libs "stdc++")
    endif()
  endif()

  list(JOIN _curl_cxx_link_libs ";" _curl_cxx_required_libs)
  if(_curl_cxx_required_libs)
    string(REPLACE ";" "\\;" _curl_cxx_required_libs_escaped "${_curl_cxx_required_libs}")
    list(APPEND _curl_platform_flags "-DCMAKE_REQUIRED_LIBRARIES=${_curl_cxx_required_libs_escaped}")

    set(_curl_cxx_link_flags "")
    foreach(_lib IN LISTS _curl_cxx_link_libs)
      if(IS_ABSOLUTE "${_lib}" OR _lib MATCHES "^-")
        string(APPEND _curl_cxx_link_flags " ${_lib}")
      else()
        string(APPEND _curl_cxx_link_flags " -l${_lib}")
      endif()
    endforeach()
    string(STRIP "${_curl_cxx_link_flags}" _curl_cxx_link_flags)
    if(_curl_cxx_link_flags)
      set(_curl_exe_linker_flags "${CMAKE_EXE_LINKER_FLAGS}")
      set(_curl_shared_linker_flags "${CMAKE_SHARED_LINKER_FLAGS}")
      string(APPEND _curl_exe_linker_flags " ${_curl_cxx_link_flags}")
      string(APPEND _curl_shared_linker_flags " ${_curl_cxx_link_flags}")
      string(STRIP "${_curl_exe_linker_flags}" _curl_exe_linker_flags)
      string(STRIP "${_curl_shared_linker_flags}" _curl_shared_linker_flags)
      list(APPEND _curl_platform_flags "-DCMAKE_EXE_LINKER_FLAGS=${_curl_exe_linker_flags}")
      list(APPEND _curl_platform_flags "-DCMAKE_SHARED_LINKER_FLAGS=${_curl_shared_linker_flags}")
    endif()
  endif()
endif()

set(_curl_http_stack_path_flags)
if(NOT WIN32)
  # Force curl to use our staged nghttp2/nghttp3/ngtcp2 artifacts. This avoids
  # accidental pickup of system/Homebrew headers, which may miss patched APIs.
  list(APPEND _curl_http_stack_path_flags
    "-DNGHTTP2_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include"
    "-DNGHTTP2_LIBRARY=${DEPS_INSTALL_DIR}/lib/libnghttp2.a"
    "-DNGHTTP3_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include"
    "-DNGHTTP3_LIBRARY=${DEPS_INSTALL_DIR}/lib/libnghttp3.a"
    "-DNGTCP2_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include"
    "-DNGTCP2_LIBRARY=${DEPS_INSTALL_DIR}/lib/libngtcp2.a"
    "-DNGTCP2_CRYPTO_BORINGSSL_LIBRARY=${DEPS_INSTALL_DIR}/lib/libngtcp2_crypto_boringssl.a"
  )
endif()

ExternalProject_Add(curl
  URL "${CURL_URL}"
  SOURCE_DIR "${DEPS_SRC_DIR}/curl"
  BINARY_DIR "${DEPS_BUILD_DIR}/curl"
  INSTALL_DIR "${CMAKE_INSTALL_PREFIX}"
  PATCH_COMMAND ${PATCH_EXE} -p1 -i "${CMAKE_SOURCE_DIR}/patches/curl.patch"
  DEPENDS ${_curl_deps}
  CONFIGURE_COMMAND
    ${CMAKE_COMMAND} -E env
      ${_curl_configure_env}
    ${CMAKE_COMMAND}
      -DCMAKE_BUILD_TYPE=Release
      ${_shadow_avoid_cmake_args}
      -DCMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}
      -DCMAKE_INSTALL_LIBDIR=lib
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_POSITION_INDEPENDENT_CODE=ON
      -DCMAKE_PREFIX_PATH=${_curl_prefix_path}
      ${_curl_use_pkgconfig_flag}
      -DCURL_USE_OPENSSL=ON
      -DCURL_ENABLE_SSL=ON
      -DOPENSSL_ROOT_DIR=${BORINGSSL_SRC_DIR}
      -DOPENSSL_INCLUDE_DIR=${BORINGSSL_SRC_DIR}/include
      -DOPENSSL_SSL_LIBRARY=${BORINGSSL_SSL_LIB}
      -DOPENSSL_CRYPTO_LIBRARY=${BORINGSSL_CRYPTO_LIB}
      -DOPENSSL_USE_STATIC_LIBS=ON
      -DCURL_BROTLI=ON
      -DCURL_ZSTD=ON
      # Make sure curl doesn't link against an unversioned .so (Linux only).
      -DZLIB_INCLUDE_DIR=${DEPS_INSTALL_DIR}/include
      -DZLIB_LIBRARY=${_curl_zlib_library}
      -DZLIB_LIBRARY_RELEASE=${_curl_zlib_library}
      -DUSE_NGHTTP2=ON
      -DUSE_NGTCP2=ON
      -DCURL_DISABLE_LDAP=ON
      -DCURL_DISABLE_LDAPS=ON
      # XXX: psl should be enabled in the future:
      # https://daniel.haxx.se/blog/2024/01/10/psl-in-curl/
      -DCURL_USE_LIBPSL=OFF
      -DUSE_LIBRTMP=OFF
      -DCURL_DISABLE_WEBSOCKETS=OFF
      -DUSE_ECH=ON
      -DUSE_SSLS_EXPORT=ON
      -DENABLE_IPV6=ON
      -DCURL_USE_LIBSSH2=OFF
      -DBUILD_MISC_DOCS=OFF
      -DENABLE_CURL_MANUAL=OFF
      ${_curl_ca_flags}
      ${_curl_idn_flags}
      ${_curl_build_flags}
      ${_curl_platform_flags}
      ${_curl_http_stack_path_flags}
      -GNinja
      -S <SOURCE_DIR> -B <BINARY_DIR>
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config Release --parallel ${SUBJOBS}
  INSTALL_COMMAND ""
)

add_custom_target(curl-impersonate ALL DEPENDS curl)

add_custom_target(curl-install
  DEPENDS curl
)

add_custom_target(install-all
  COMMAND ${CMAKE_COMMAND} --build ${CMAKE_BINARY_DIR} --target curl-install
  COMMAND ${CMAKE_COMMAND} --install ${CMAKE_BINARY_DIR}
)

# Install only runtime artifacts we ship: curl binary, libcurl library, and wrappers.
# Do not call curl's own install target, which also installs docs/manpages.
if(WIN32)
  install(PROGRAMS "${DEPS_BUILD_DIR}/curl/src/curl-impersonate.exe" DESTINATION ${CMAKE_INSTALL_BINDIR})
else()
  install(PROGRAMS "${DEPS_BUILD_DIR}/curl/src/curl-impersonate" DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()
if(WIN32)
  install(
    DIRECTORY "${DEPS_BUILD_DIR}/curl/lib/"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
    FILES_MATCHING
      PATTERN "libcurl-impersonate*.lib"
      PATTERN "libcurl-impersonate*.a"
      PATTERN "libcurl-impersonate*.dll"
  )
else()
  install(
    DIRECTORY "${DEPS_BUILD_DIR}/curl/lib/"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
    FILES_MATCHING
      PATTERN "libcurl-impersonate*.a"
      PATTERN "libcurl-impersonate*.so*"
      PATTERN "libcurl-impersonate*.dylib*"
  )
endif()
if(WIN32)
  file(GLOB _curl_wrapper_scripts CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/win/bin/curl_*.bat")
else()
  file(GLOB _curl_wrapper_scripts CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/bin/curl_*")
endif()
if(_curl_wrapper_scripts)
  install(PROGRAMS ${_curl_wrapper_scripts} DESTINATION ${CMAKE_INSTALL_BINDIR})
endif()

configure_file(
  "${CMAKE_SOURCE_DIR}/cmake/Uninstall.cmake.in"
  "${CMAKE_BINARY_DIR}/cmake_uninstall.cmake"
  @ONLY
)

add_custom_target(uninstall
  COMMAND ${CMAKE_COMMAND} -P "${CMAKE_BINARY_DIR}/cmake_uninstall.cmake"
  COMMENT "Uninstall files recorded in install manifests"
)
