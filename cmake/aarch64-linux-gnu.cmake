# SPDX-License-Identifier: Apache-2.0

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(CMAKE_AR aarch64-linux-gnu-ar)
set(CMAKE_RANLIB aarch64-linux-gnu-ranlib)
set(CMAKE_STRIP aarch64-linux-gnu-strip)

# Programs such as protoc must run on the amd64 build host. Libraries and
# headers must come from the arm64 multiarch packages.
set(PT_TARGET_ROOT "/" CACHE PATH "Root containing Ubuntu arm64 packages")
if(PT_TARGET_ROOT STREQUAL "/")
    set(PT_MULTIARCH_LIBDIR /usr/lib/aarch64-linux-gnu)
    set(PT_PKG_CONFIG_SYSROOT "")
else()
    set(PT_MULTIARCH_LIBDIR ${PT_TARGET_ROOT}/usr/lib/aarch64-linux-gnu)
    set(PT_PKG_CONFIG_SYSROOT ${PT_TARGET_ROOT})
endif()

set(CMAKE_FIND_ROOT_PATH
    ${PT_TARGET_ROOT}
    /usr/aarch64-linux-gnu
    ${PT_MULTIARCH_LIBDIR})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

set(Protobuf_USE_STATIC_LIBS ON CACHE BOOL "Link protobuf statically")

set(ENV{PKG_CONFIG_LIBDIR}
    "${PT_MULTIARCH_LIBDIR}/pkgconfig:${PT_TARGET_ROOT}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_PATH} "")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "${PT_PKG_CONFIG_SYSROOT}")
