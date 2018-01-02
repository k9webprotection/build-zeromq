#!/bin/bash
TOOLCHAIN_ROOT="${OBJDIR_ROOT}/objdir-${TARGET}/build/standalone-toolchain"
[ -d "${TOOLCHAIN_ROOT}" ] || {
    echo -n "Preparing standalone toolchain for ${PLATFORM_ARCH} version ${ANDROID_PLATFORM}..."
    "${ANDROID_NDK_HOME}/build/tools/make_standalone_toolchain.py" --arch ${PLATFORM_ARCH} \
                                                                   --api ${ANDROID_PLATFORM} \
                                                                   --stl libc++ \
                                                                   --install-dir "${TOOLCHAIN_ROOT}" || exit $?
    echo "Done"
}

PFIX="${TOOLCHAIN_ROOT}/bin/${HOST}"
export CC="${PFIX}-clang"
export CXX="${PFIX}-clang++"
export RANLIB="${PFIX}-ranlib"
export AR="${PFIX}-ar"
export AS="${PFIX}-as"
export CPP="${PFIX}-cpp"
export LD="${PFIX}-ld"
export STRIP="${PFIX}-strip"
export CPPFLAGS="${COMP_FLAGS}"
