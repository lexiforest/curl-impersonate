cmake_minimum_required(VERSION 3.20)

foreach(_required INPUT_PC DEPENDENCY_PREFIX LIBRARY_DIR ARCHIVES)
  if(NOT DEFINED ${_required} OR "${${_required}}" STREQUAL "")
    message(FATAL_ERROR "${_required} is required")
  endif()
endforeach()

find_program(PKG_CONFIG pkg-config REQUIRED)
get_filename_component(_pc_dir "${INPUT_PC}" DIRECTORY)
get_filename_component(_pc_name "${INPUT_PC}" NAME_WE)
set(_pkg_config_command
  "${CMAKE_COMMAND}" -E env
  "PKG_CONFIG_PATH="
  "PKG_CONFIG_LIBDIR=${_pc_dir}:${DEPENDENCY_PREFIX}/lib/pkgconfig:${DEPENDENCY_PREFIX}/share/pkgconfig"
  "PKG_CONFIG_SYSROOT_DIR="
  "${PKG_CONFIG}"
)
# Resolve private dependencies while their original pkg-config files are available.
execute_process(
  COMMAND ${_pkg_config_command} --static --libs "${_pc_name}"
  OUTPUT_VARIABLE _options
  OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY
)
execute_process(
  COMMAND ${_pkg_config_command} --variable=libdir "${_pc_name}"
  OUTPUT_VARIABLE _original_libdir
  OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY
)
get_filename_component(_original_libdir "${_original_libdir}" REALPATH)
get_filename_component(_dependency_libdir "${DEPENDENCY_PREFIX}/lib" REALPATH)

set(_bundled_flags -lcurl-impersonate)
foreach(_archive IN LISTS ARCHIVES)
  get_filename_component(_archive "${_archive}" ABSOLUTE BASE_DIR "${LIBRARY_DIR}")
  if(NOT EXISTS "${_archive}")
    message(FATAL_ERROR "Missing bundled archive: ${_archive}")
  endif()
  get_filename_component(_name "${_archive}" NAME)
  if(NOT _name MATCHES "^lib(.+)\\.a$")
    message(FATAL_ERROR "Unexpected archive name: ${_archive}")
  endif()
  list(APPEND _bundled_flags "-l${CMAKE_MATCH_1}")
endforeach()

separate_arguments(_options UNIX_COMMAND "${_options}")
set(_system_options)
foreach(_option IN LISTS _options)
  if(_option IN_LIST _bundled_flags)
    continue()
  elseif(_option MATCHES "^-L(.+)$")
    get_filename_component(_libdir "${CMAKE_MATCH_1}" REALPATH)
    if(NOT _libdir STREQUAL _original_libdir AND
       NOT _libdir STREQUAL _dependency_libdir AND
       NOT _libdir STREQUAL "/usr/lib")
      message(FATAL_ERROR "Unbundled library search path: ${_option}")
    endif()
  else()
    list(APPEND _system_options "${_option}")
  endif()
endforeach()
list(JOIN _system_options " " _system_options)

execute_process(
  COMMAND ${_pkg_config_command} --modversion "${_pc_name}"
  OUTPUT_VARIABLE CURL_VERSION
  OUTPUT_STRIP_TRAILING_WHITESPACE
  COMMAND_ERROR_IS_FATAL ANY
)
set(CURL_SYSTEM_LIBS "${_system_options}")
configure_file("${CMAKE_CURRENT_LIST_DIR}/libcurl-impersonate.pc.in"
  "${LIBRARY_DIR}/libcurl-impersonate.pc" @ONLY)
message(STATUS "Release system dependencies: ${CURL_SYSTEM_LIBS}")
