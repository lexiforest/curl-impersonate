# Loaded by the curl subproject after project(), before libcurl is defined.
# Compile the bridge into libcurl so only its documented API is exported;
# BoringSSL implementation symbols remain private in the static dependency.
enable_language(CXX)
function(curl_impersonate_webcrypto)
  foreach(target libcurl_shared libcurl_static)
    if(TARGET ${target})
      target_sources(${target} PRIVATE "${CURL_IMPERSONATE_SOURCE_DIR}/src/webcrypto.cc")
      target_include_directories(${target} PRIVATE "${CURL_IMPERSONATE_SOURCE_DIR}/include")
      if(target STREQUAL "libcurl_static")
        target_compile_definitions(${target} PUBLIC BSSL_WEBCRYPTO_STATIC)
      endif()
      set_property(TARGET ${target} PROPERTY CXX_STANDARD 17)
      set_property(TARGET ${target} PROPERTY CXX_STANDARD_REQUIRED ON)
    endif()
  endforeach()
endfunction()
cmake_language(DEFER CALL curl_impersonate_webcrypto)
