#!/bin/bash

LIPO_PATH="$(which lipo)"
GEN_SCRIPT="${CONFIGS_DIR}/common-clang-darwin.sh"

CLANG_PATH="$(xcrun -f clang)"
SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
SDK_VERSION_NAME="macosx"
MIN_OS_VERSION="${MIN_OS_VERSION:-10.9}"
