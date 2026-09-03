# SPDX-License-Identifier: Apache-2.0

# The standalone Android build files link a target named `z`. Define it before
# the vendor targets are created so every packaged executable uses the arm64
# static archive instead of depending on the distribution's libz.so.1.
if(NOT DEFINED PT_TARGET_ROOT)
    message(FATAL_ERROR "PT_TARGET_ROOT must be set")
endif()

if(PT_TARGET_ROOT STREQUAL "/")
    set(PT_ZLIB_ARCHIVE /usr/lib/aarch64-linux-gnu/libz.a)
else()
    set(PT_ZLIB_ARCHIVE ${PT_TARGET_ROOT}/usr/lib/aarch64-linux-gnu/libz.a)
endif()

if(NOT EXISTS ${PT_ZLIB_ARCHIVE})
    message(FATAL_ERROR "arm64 static zlib archive is missing: ${PT_ZLIB_ARCHIVE}")
endif()

add_library(z STATIC IMPORTED GLOBAL)
set_target_properties(z PROPERTIES IMPORTED_LOCATION ${PT_ZLIB_ARCHIVE})

