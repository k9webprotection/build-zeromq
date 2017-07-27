#!/bin/bash
# We need to hack the mm_malloc.h file since it's not right - see https://android-review.googlesource.com/#/c/280335/
cat "${PREBUILT_ROOT}/lib/gcc/${GCC_PREFIX}/${ANDROID_GCC_VERSION}.x/include/mm_malloc.h" | \
    sed -e 's/throw ()//g' > mm_malloc.h
