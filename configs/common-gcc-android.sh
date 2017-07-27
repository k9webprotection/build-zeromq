#!/bin/bash

PREBUILT_ROOT="${ANDROID_NDK_HOME}/toolchains/${GCC_ARCH}-${ANDROID_GCC_VERSION}/prebuilt/darwin-x86_64"
PFIX="${PREBUILT_ROOT}/bin/${GCC_PREFIX}"
HOST="arm-linux-androideabi"

export SYSROOT="${ANDROID_NDK_HOME}/platforms/android-${ANDROID_PLATFORM}/arch-${PLATFORM_ARCH}"
export CROSS_SYSROOT="${SYSROOT}"
export ANDROID_DEV="${CROSS_SYSROOT}/usr"
export CC="${PFIX}-gcc"
export RANLIB="${PFIX}-ranlib"
export AR="${PFIX}-ar"
export AS="${PFIX}-as"
export CPP="${PFIX}-cpp"
export CXX="${PFIX}-g++"
export LD="${PFIX}-ld"
export STRIP="${PFIX}-strip"
export CFLAGS="--sysroot=${CROSS_SYSROOT} ${COMP_FLAGS}"
export CPPFLAGS="--sysroot=${CROSS_SYSROOT} -isystem${CXX_STL_ROOT}/include \
                                            -isystem${CXX_STL_ROOT}/libs/${CXX_STL_ARCH}/include \
                                            -isystem${CXX_STL_ROOT}/include/backward \
                                            ${COMP_FLAGS}"
export LDFLAGS="--sysroot=${CROSS_SYSROOT} -L${CXX_STL_ROOT}/libs/${CXX_STL_ARCH}"
export LIBS="-lgnustl_static" 

ANDROID_BUILD_PIE="${ANDROID_BUILD_PIE:-true}"
if [ "${ANDROID_BUILD_PIE}" == "true" ]; then
    export CFLAGS="${CFLAGS} -fPIE"
    export CPPFLAGS="${CPPFLAGS} -fPIE"
    export LDFLAGS="${LDFLAGS} -fPIE -pie"
fi
