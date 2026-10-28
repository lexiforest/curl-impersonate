# Loaded by the curl subproject after project(), before libcurl is defined.
# Compile the bridge into libcurl so only its documented API is exported;
# BoringSSL implementation symbols remain private in the static dependency.
enable_language(CXX)
function(curl_impersonate_webcrypto)
  foreach(target libcurl_shared libcurl_static)
    if(TARGET ${target})
      target_sources(${target} PRIVATE "${BORINGSSL_WEBCRYPTO_SOURCE_DIR}/crypto/webcrypto/webcrypto.cc")
      target_include_directories(${target} PRIVATE "${BORINGSSL_WEBCRYPTO_SOURCE_DIR}/include")
      set_property(TARGET ${target} PROPERTY CXX_STANDARD 17)
      set_property(TARGET ${target} PROPERTY CXX_STANDARD_REQUIRED ON)
    endif()
  endforeach()
endfunction()
cmake_language(DEFER CALL curl_impersonate_webcrypto)
