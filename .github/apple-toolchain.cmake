# CMAKE_TOOLCHAIN_FILE is inherited by every ExternalProject and try_compile.
set(CMAKE_OSX_ARCHITECTURES "$ENV{APPLE_ARCH}" CACHE STRING "Target architecture")
set(CMAKE_OSX_SYSROOT "$ENV{SDKROOT}" CACHE PATH "Apple SDK")
set(CMAKE_OSX_DEPLOYMENT_TARGET "$ENV{APPLE_MIN_VERSION}" CACHE STRING "Minimum OS version")
if(NOT "$ENV{APPLE_SDK}" STREQUAL "macosx")
  set(CMAKE_SYSTEM_NAME iOS)
elseif(NOT "$ENV{APPLE_ARCH}" STREQUAL "${CMAKE_HOST_SYSTEM_PROCESSOR}")
  set(CMAKE_SYSTEM_NAME Darwin)
endif()
set(CMAKE_SYSTEM_PROCESSOR "$ENV{APPLE_ARCH}")

# CI packages the libraries and CLI and runs this repository's consumer checks.
set(BUILD_TESTING OFF CACHE BOOL "Build upstream tests")
set(BUILD_EXAMPLES OFF CACHE BOOL "Build upstream examples")
set(BUILD_LIBCURL_DOCS OFF CACHE BOOL "Build libcurl man pages")
