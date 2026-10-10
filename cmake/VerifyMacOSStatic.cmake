cmake_minimum_required(VERSION 3.20)

foreach(_required ARCHIVE WORK_DIR COMPILER ARCHITECTURE)
  if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
    message(FATAL_ERROR "${_required} is required")
  endif()
endforeach()

set(_release "${WORK_DIR}/release with spaces")
if(EXISTS "${_release}")
  message(FATAL_ERROR "Use a fresh WORK_DIR: ${WORK_DIR}")
endif()
file(MAKE_DIRECTORY "${_release}")
file(ARCHIVE_EXTRACT INPUT "${ARCHIVE}" DESTINATION "${_release}")
file(REAL_PATH "${_release}" _release_real)
find_program(PKG_CONFIG pkg-config REQUIRED)
set(_pkg_config_command
  "${CMAKE_COMMAND}" -E env
  "PKG_CONFIG_PATH=" "PKG_CONFIG_LIBDIR=${_release}" "PKG_CONFIG_SYSROOT_DIR="
  "${PKG_CONFIG}"
)
execute_process(
  COMMAND ${_pkg_config_command} --static --cflags --libs libcurl-impersonate
  OUTPUT_VARIABLE _flags
  OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY
  TIMEOUT 30
)
message(STATUS "Relocated pkg-config metadata: ${_flags}")

# Deliberately do not pass pkg-config flags: match existing force-load consumers.
separate_arguments(_compiler UNIX_COMMAND "${COMPILER}")
set(_program "${WORK_DIR}/static-autolink")
execute_process(
  COMMAND ${_compiler} -arch "${ARCHITECTURE}"
    "${CMAKE_CURRENT_LIST_DIR}/../tests/static-autolink.c"
    "-I${_release}/include" "-Wl,-force_load,${_release}/libcurl-impersonate.a"
    -lc++ -o "${_program}"
  COMMAND_ERROR_IS_FATAL ANY
  TIMEOUT 120
)

# Independently test the .pc: embedded hints must not hide missing private flags.
separate_arguments(_pc_flags UNIX_COMMAND "${_flags}")
set(_pc_libdirs)
foreach(_flag IN LISTS _pc_flags)
  if(_flag MATCHES "^-[IL](.+)$")
    # Existing build directories must not make non-relocatable metadata pass.
    file(REAL_PATH "${CMAKE_MATCH_1}" _search_path)
    cmake_path(IS_PREFIX _release_real "${_search_path}" NORMALIZE _in_release)
    if(NOT _in_release)
      message(FATAL_ERROR "pkg-config search path escapes the extracted release: ${_flag}")
    endif()
  endif()
  if(_flag MATCHES "^-L(.+)$")
    list(APPEND _pc_libdirs "${CMAKE_MATCH_1}")
  endif()
endforeach()
# Search only metadata-provided paths, and never choose the adjacent dylib.
find_file(_pc_archive NAMES libcurl-impersonate.a
  PATHS ${_pc_libdirs} NO_DEFAULT_PATH REQUIRED)
file(REAL_PATH "${_pc_archive}" _pc_archive_real)
if(NOT _pc_archive_real STREQUAL "${_release_real}/libcurl-impersonate.a")
  message(FATAL_ERROR "pkg-config selected an archive outside the extracted release: ${_pc_archive}")
endif()
set(_pc_link_flags)
foreach(_flag IN LISTS _pc_flags)
  if(_flag STREQUAL "-lcurl-impersonate")
    list(APPEND _pc_link_flags "${_pc_archive}")
  else()
    list(APPEND _pc_link_flags "${_flag}")
  endif()
endforeach()
set(_pc_program "${WORK_DIR}/static-pkgconfig")
execute_process(
  COMMAND ${_compiler} -arch "${ARCHITECTURE}" -Wl,-ignore_auto_link
    "${CMAKE_CURRENT_LIST_DIR}/../tests/static-autolink.c" ${_pc_link_flags}
    -o "${_pc_program}"
  COMMAND_ERROR_IS_FATAL ANY
  TIMEOUT 120
)

set(_payload "pkg-config automatic static link consumer\n")
set(_input "${WORK_DIR}/input.txt")
file(WRITE "${_input}" "${_payload}")
string(REPLACE "%" "%25" _url "${_input}")
string(REPLACE " " "%20" _url "${_url}")
string(REPLACE "#" "%23" _url "${_url}")
string(REPLACE "?" "%3F" _url "${_url}")
find_program(OTOOL otool REQUIRED)
foreach(_consumer "${_program}" "${_pc_program}")
  execute_process(
    COMMAND "${_consumer}" "file://${_url}"
    OUTPUT_VARIABLE _actual
    COMMAND_ERROR_IS_FATAL ANY
    TIMEOUT 30
  )
  if(NOT _actual STREQUAL _payload)
    message(FATAL_ERROR "${_consumer} returned incorrect file contents")
  endif()
  execute_process(
    COMMAND "${OTOOL}" -L "${_consumer}"
    OUTPUT_VARIABLE _dependencies
    COMMAND_ERROR_IS_FATAL ANY
  )
  if(_dependencies MATCHES "libcurl-impersonate[^\n]*\\.dylib")
    message(FATAL_ERROR "${_consumer} unexpectedly linked libcurl-impersonate.dylib")
  endif()
endforeach()
find_program(LIPO lipo REQUIRED)
foreach(_binary "${_release}/libcurl-impersonate.a" "${_program}" "${_pc_program}")
  execute_process(
    COMMAND "${LIPO}" -archs "${_binary}"
    OUTPUT_VARIABLE _architecture
    OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY
  )
  if(NOT _architecture STREQUAL ARCHITECTURE)
    message(FATAL_ERROR "Unexpected architecture in ${_binary}: ${_architecture}")
  endif()
endforeach()
message(STATUS "Relocated ${ARCHITECTURE} consumers passed: automatic linking and independent pkg-config")
