cmake_minimum_required(VERSION 3.20)

foreach(_required INPUT_PC DEPENDENCY_PREFIX ARCHIVE_DIR ARCHIVES OUTPUT_PC OUTPUT_ASM)
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
  get_filename_component(_archive "${_archive}" ABSOLUTE BASE_DIR "${ARCHIVE_DIR}")
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
set(_assembly ".section __TEXT,__text\n")
while(_options)
  list(POP_FRONT _options _option)
  if(_option IN_LIST _bundled_flags)
    continue()
  elseif(_option MATCHES "^-L(.+)$")
    get_filename_component(_libdir "${CMAKE_MATCH_1}" REALPATH)
    if(NOT _libdir STREQUAL _original_libdir AND
       NOT _libdir STREQUAL _dependency_libdir AND
       NOT _libdir STREQUAL "/usr/lib")
      message(FATAL_ERROR "Unbundled library search path: ${_option}")
    endif()
  elseif(_option STREQUAL "-framework")
    if(NOT _options)
      message(FATAL_ERROR "Missing framework name in pkg-config output")
    endif()
    list(POP_FRONT _options _framework)
    if(NOT _framework MATCHES "^[A-Za-z0-9_]+$")
      message(FATAL_ERROR "Unsupported framework name: ${_framework}")
    endif()
    list(APPEND _system_options "-framework" "${_framework}")
    string(APPEND _assembly ".linker_option \"-framework\", \"${_framework}\"\n")
  elseif(_option MATCHES "^-l[A-Za-z0-9_.+-]+$")
    list(APPEND _system_options "${_option}")
    string(APPEND _assembly ".linker_option \"${_option}\"\n")
  else()
    message(FATAL_ERROR "Unsupported macOS automatic link option: ${_option}")
  endif()
endwhile()
list(JOIN _system_options " " _system_options)

# Both forms describe the same merged archive; neither retains staging paths.
file(READ "${INPUT_PC}" _pc)
string(REGEX REPLACE "\nprefix=[^\n]*" "\nprefix=\${pcfiledir}" _pc "${_pc}")
string(REGEX REPLACE "\nexec_prefix=[^\n]*" "\nexec_prefix=\${prefix}" _pc "${_pc}")
string(REGEX REPLACE "\nlibdir=[^\n]*" "\nlibdir=\${prefix}" _pc "${_pc}")
string(REGEX REPLACE "\nincludedir=[^\n]*" "\nincludedir=\${prefix}/include" _pc "${_pc}")
string(REGEX REPLACE "\nName:[^\n]*" "\nName: libcurl-impersonate" _pc "${_pc}")
string(REGEX REPLACE "\nRequires(\\.private)?:[^\n]*" "" _pc "${_pc}")
string(REGEX REPLACE "\nLibs:[^\n]*" "\nLibs: -L\${libdir} -lcurl-impersonate" _pc "${_pc}")
string(REGEX REPLACE "\nLibs\\.private:[^\n]*" "\nLibs.private: ${_system_options}" _pc "${_pc}")
file(WRITE "${OUTPUT_PC}" "${_pc}")
file(WRITE "${OUTPUT_ASM}" "${_assembly}")
message(STATUS "macOS static system dependencies: ${_system_options}")
