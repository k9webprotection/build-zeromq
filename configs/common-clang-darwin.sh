#!/bin/bash

SDK_FLAG="${SDK_VERSION_NAME}-version-min=${MIN_OS_VERSION}"
OPT_FLAG="${OPT_FLAG:--O3 -Wno-inline}"
HOST="${HOST_ARCH}-apple-darwin"

export CC="${CLANG_PATH}"
export CPPFLAGS="-arch ${ARCH} -m${SDK_FLAG} -isysroot ${SDK_PATH} -fPIC -fembed-bitcode"
export CFLAGS="${OPT_FLAG}"
export CXXFLAGS="${OPT_FLAG}"
export LDFLAGS="-arch ${ARCH} -m${SDK_FLAG} -isysroot ${SDK_PATH}"
