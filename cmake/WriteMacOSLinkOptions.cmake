cmake_minimum_required(VERSION 3.20)

# Write a Clang response file for the system dependencies of the merged archive.
# The shared and static libraries are built with the same curl configuration.
if(NOT DEFINED LIBRARY OR NOT DEFINED OUTPUT)
  message(FATAL_ERROR "LIBRARY and OUTPUT are required")
endif()

find_program(OTOOL otool REQUIRED)
execute_process(
  COMMAND "${OTOOL}" -D "${LIBRARY}"
  OUTPUT_VARIABLE _install_names
  COMMAND_ERROR_IS_FATAL ANY
)
execute_process(
  COMMAND "${OTOOL}" -L "${LIBRARY}"
  OUTPUT_VARIABLE _dependencies
  COMMAND_ERROR_IS_FATAL ANY
)
string(REPLACE "\n" ";" _install_names "${_install_names}")
string(REPLACE "\n" ";" _dependencies "${_dependencies}")
set(_options "")
foreach(_line IN LISTS _dependencies)
  if(NOT _line MATCHES "^[ \t]+(.+) \\(compatibility version [^,]+, current version [^)]+\\)$")
    continue()
  endif()
  set(_dependency "${CMAKE_MATCH_1}")
  if(_dependency IN_LIST _install_names)
    continue()
  endif()
  if(_dependency MATCHES "^/System/Library/Frameworks/([A-Za-z0-9_]+)\\.framework/")
    string(APPEND _options "-framework\n${CMAKE_MATCH_1}\n")
  elseif(_dependency MATCHES "^/usr/lib/lib([A-Za-z0-9_.+-]+)\\.dylib$")
    string(APPEND _options "-l${CMAKE_MATCH_1}\n")
  else()
    message(FATAL_ERROR "Non-system dependency in ${LIBRARY}: ${_dependency}")
  endif()
endforeach()
if(_options STREQUAL "")
  message(FATAL_ERROR "No system dependencies found in ${LIBRARY}")
endif()
file(WRITE "${OUTPUT}" "${_options}")
