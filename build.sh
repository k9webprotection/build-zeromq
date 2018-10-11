#!/bin/bash

cd "$(dirname "${0}")"
BUILD_DIR="$(pwd)"
cd ->/dev/null

# Homebrew bootstrapping information
: ${HB_BOOTSTRAP_GIST_URL:="https://gist.githubusercontent.com/toonetown/48101686e509fda81335/raw"}
HB_BOOTSTRAP="t:*toonetown/android b:android-ndk 
              b:autoconf b:automake b:libtool b:dos2unix
              t:toonetown/extras b:toonetown-extras s:toonetown-extras b:android-env"

# Overridable build locations
: ${DEFAULT_LIBZMQ_DIST:="${BUILD_DIR}/libzmq"}
: ${DEFAULT_CPPZMQ_DIST:="${BUILD_DIR}/bindings/cppzmq"}
: ${DEFAULT_ZMQCPP_DIST:="${BUILD_DIR}/bindings/zmqcpp"}
: ${DEFAULT_AZMQ_DIST:="${BUILD_DIR}/bindings/azmq"}
: ${OBJDIR_ROOT:="${BUILD_DIR}/target"}
: ${CONFIGS_DIR:="${BUILD_DIR}/configs"}
: ${MAKE_BUILD_PARALLEL:=$(sysctl -n hw.ncpu)}

# Packages to bundle - macosx last, so we get the right line endings
: ${PKG_COMBINED_PLATS:="windows.i386 windows.x86_64 macosx"}

# Options for ZeroMQ build options
: ${COMMON_LIBZMQ_BUILD_OPTIONS:="--enable-static --disable-shared"}
: ${LIBZMQ_BUILD_OPTIONS:="--disable-eventfd --with-libsodium=no"}

# Include files to copy
CPPZMQ_INCLUDE_FILES="zmq.hpp zmq_addon.hpp"
ZMQCPP_INCLUDE_FILES="include/zmqcpp.h"
AZMQ_INCLUDE_DIRS="azmq"

list_arch() {
    if [ -z "${1}" ]; then
        PFIX="${CONFIGS_DIR}/setup-*"
    else
        PFIX="${CONFIGS_DIR}/setup-${1}"
    fi
    ls -m ${PFIX}.*.sh 2>/dev/null | sed "s#${CONFIGS_DIR}/setup-\(.*\)\.sh#\1#" | \
                         tr -d '\n' | \
                         sed -e 's/ \+/ /g' | sed -e 's/^ *\(.*\) *$/\1/g'
}

list_plats() {
    for i in $(list_arch | sed -e 's/,//g'); do
        echo "${i}" | cut -d'.' -f1
    done | sort -u
}

print_usage() {
    while [ $# -gt 0 ]; do
        echo "${1}" >&2
        shift 1
        if [ $# -eq 0 ]; then echo "" >&2; fi
    done
    echo "Usage: ${0} [/path/to/libzmq-dist] [/paths/to/bindings...] <plat.arch|plat|'bootstrap'|'clean'>"    >&2
    echo ""                                                                                                   >&2
    echo "\"/path/to/libzmq-dist\" is optional and defaults to:"                                              >&2
    echo "    \"${DEFAULT_LIBZMQ_DIST}\""                                                                     >&2
    echo "\"/paths/to/bindings\" is one or more optional paths to binding distributions, required are:"       >&2
    echo "    \"/path/to/cppzmq-dist\" is optional and defaults to:"                                          >&2
    echo "        \"${DEFAULT_CPPZMQ_DIST}\""                                                                 >&2
    echo "    \"/path/to/zmqcpp-dist\" is optional and defaults to:"                                          >&2
    echo "        \"${DEFAULT_ZMQCPP_DIST}\""                                                                 >&2
    echo "    \"/path/to/azmq-dist\" is optional and defaults to:"                                            >&2
    echo "        \"${DEFAULT_AZMQ_DIST}\""                                                                   >&2
    echo ""                                                                                                   >&2
    echo "Possible plat.arch combinations are:"                                                               >&2
    for p in $(list_plats); do
        echo "    ${p}:"                                                                                      >&2
        echo "        $(list_arch ${p})"                                                                      >&2
        echo ""                                                                                               >&2
    done
    echo "If you specify just a plat, then *all* architectures will be built for that"                        >&2
    echo "platform, and the resulting libraries will be \"lipo\"-ed together to a single"                     >&2
    echo "fat binary (if supported)."                                                                         >&2
    echo ""                                                                                                   >&2
    echo "When specifying clean, you may optionally include a plat or plat.arch to clean,"                    >&2
    echo "i.e. \"${0} clean macosx.i386\" to clean only the i386 architecture on Mac OS X"                    >&2
    echo "or \"${0} clean ios\" to clean all ios builds."                                                     >&2
    echo ""                                                                                                   >&2
    echo "You can copy the windows outputs to non-windows target directory by running"                        >&2
    echo "\"${0} copy-windows /path/to/windows/target"                                                        >&2
    echo ""                                                                                                   >&2
    echo "You can specify to package the release (after it's already been built) by"                          >&2
    echo "running \"${0} package /path/to/output"                                                             >&2
    echo ""                                                                                                   >&2
    return 1
}

do_bootstrap() {
    curl -sSL "${HB_BOOTSTRAP_GIST_URL}" | /bin/bash -s -- ${HB_BOOTSTRAP}
}

do_build_libzmq() {
    TARGET="${1}"
    OUTPUT_ROOT="${2}"
    BUILD_ROOT="${OUTPUT_ROOT}/build/libzmq"

    [ -d "${BUILD_ROOT}" -a -f "${BUILD_ROOT}/configure" ] || {
        echo "Creating build directory for '${TARGET}'..."
        mkdir -p "$(dirname "${BUILD_ROOT}")" || return $?
        cp -r "${PATH_TO_LIBZMQ_DIST}" "${BUILD_ROOT}" || return $?
        cd "${BUILD_ROOT}" || return $?
        ./autogen.sh || {
            rm -f "${BUILD_ROOT}/configure"
            return 1
        }
        cd ->/dev/null
    }
    
    if [ ! -f "${BUILD_ROOT}/config.status" ]; then
        echo "Configuring LibZMQ build directory for '${TARGET}'..."
        cd "${BUILD_ROOT}" || return $?
        [ -n "${LIBZMQ_PRECONFIGURE}" ] && {
            [ -x "${LIBZMQ_PRECONFIGURE}" ] || { echo "${LIBZMQ_PRECONFIGURE} does not exist"; return 1; }
            source "${LIBZMQ_PRECONFIGURE}" || return $?
        }
        ./configure --prefix="${OUTPUT_ROOT}" --host="${HOST}" \
                    ${COMMON_LIBZMQ_BUILD_OPTIONS} ${LIBZMQ_BUILD_OPTIONS} || {
            rm -f "${BUILD_ROOT}/Makefile"
            return 1
        }
        cd ->/dev/null
    fi
    
    cd "${BUILD_ROOT}"
    echo "Building LibZMQ architecture '${TARGET}'..."
    
    # Generate the project and build (and clean up cruft directories)
    make -j ${MAKE_BUILD_PARALLEL} && make install
    ret=$?
    rm -rf "${OUTPUT_ROOT}"/{lib/pkgconfig} >/dev/null 2>&1
    
    cd ->/dev/null
    return ${ret}
}

do_build() {
    TARGET="${1}"; shift
    PLAT="$(echo "${TARGET}" | cut -d'.' -f1)"
    ARCH="$(echo "${TARGET}" | cut -d'.' -f2)"
    CONFIG_SETUP="${CONFIGS_DIR}/setup-${TARGET}.sh"
    
    # Clean here - in case we pass a "clean" command
    if [ "${1}" == "clean" ]; then do_clean ${TARGET}; return $?; fi

    if [ -f "${CONFIG_SETUP}" -a "${PLAT}" != "${ARCH}" ]; then
        # Load configuration files
        [ -f "${CONFIGS_DIR}/setup-${PLAT}.sh" ] && {
            source "${CONFIGS_DIR}/setup-${PLAT}.sh"    || return $?
        }
        source "${CONFIG_SETUP}" && source "${GEN_SCRIPT}" || return $?
        do_build_libzmq ${TARGET} "${OBJDIR_ROOT}/objdir-${TARGET}" || return $?
        
        # Copy the cppzmq include files
        for h in ${CPPZMQ_INCLUDE_FILES}; do
            ODIR="${OBJDIR_ROOT}/objdir-${TARGET}/include/$(dirname "${h}")"
            mkdir -p "${ODIR}" || return $?
            cp "${PATH_TO_CPPZMQ_DIST}/${h}" "${ODIR}/" || return $?
        done
        # Copy the zmqcpp include files
        for h in ${ZMQCPP_INCLUDE_FILES}; do
            ODIR="${OBJDIR_ROOT}/objdir-${TARGET}/$(dirname "${h}")"
            mkdir -p "${ODIR}" || return $?
            cp "${PATH_TO_ZMQCPP_DIST}/${h}" "${ODIR}" || return $?
        done
        # Copy the amzq include files
        for h in ${AZMQ_INCLUDE_DIRS}; do
            ODIR="${OBJDIR_ROOT}/objdir-${TARGET}/include/$(dirname "${h}")"
            mkdir -p "${ODIR}" || return $?
            cp -r "${PATH_TO_AZMQ_DIST}/${h}" "${ODIR}/" || return $?
        done
    elif [ -n "${TARGET}" -a -n "$(list_arch ${TARGET})" ]; then
        PLATFORM="${TARGET}"

        # Load configuration file for the platform
        [ -f "${CONFIGS_DIR}/setup-${PLATFORM}.sh" ] && {
            source "${CONFIGS_DIR}/setup-${PLATFORM}.sh"    || return $?
        }
        
        if [ -n "${LIPO_PATH}" ]; then
            echo "Building fat binary for platform '${PLATFORM}'..."
        else
            echo "Building all architectures for platform '${PLATFORM}'..."
        fi

        COMBINED_ARCHS="$(list_arch ${PLATFORM} | sed -e 's/,//g')"
        for a in ${COMBINED_ARCHS}; do
            do_build ${a} || return $?
        done
        
        # Combine platform-specific headers
        COMBINED_ROOT="${OBJDIR_ROOT}/objdir-${PLATFORM}"
        mkdir -p "${COMBINED_ROOT}" || return $?
        cp -r ${COMBINED_ROOT}.*/include ${COMBINED_ROOT} || return $?
        _CMB_INC="${COMBINED_ROOT}/include"
        
        if [ -n "${LIPO_PATH}" ]; then
            # Set up variables to get our libraries to lipo
            PLATFORM_DIRS="$(find ${OBJDIR_ROOT} -type d -name "objdir-${PLATFORM}.*" -depth 1)"
            PLATFORM_LIBS="$(find ${PLATFORM_DIRS} -type d -name "lib" -depth 1)"
            FAT_OUTPUT="${COMBINED_ROOT}/lib"

            mkdir -p "${FAT_OUTPUT}" || return $?
            for l in $(find ${PLATFORM_LIBS} -type f -name '*.a' -exec basename {} \; | sort -u); do
                echo "Running lipo for library '${l}'..."
                ${LIPO_PATH} -create $(find ${PLATFORM_LIBS} -type f -name "${l}") -output "${FAT_OUTPUT}/${l}"
            done
        fi
    else
        print_usage "Missing/invalid target '${TARGET}'"
    fi
    return $?
}

do_clean() {
    if [ -n "${1}" ]; then
        echo "Cleaning up ${1} builds in \"${OBJDIR_ROOT}\"..."
        rm -rf "${OBJDIR_ROOT}/objdir-${1}" "${OBJDIR_ROOT}/objdir-${1}."*
    else
        echo "Cleaning up all builds in \"${OBJDIR_ROOT}\"..."
        rm -rf "${OBJDIR_ROOT}/objdir-"*  
    fi
    
    # Remove some leftovers (an empty OBJDIR_ROOT)
    rmdir "${OBJDIR_ROOT}" >/dev/null 2>&1
    return 0
}

do_copy_windows() {
    [ -d "${1}" ] || {
        print_usage "Invalid windows target directory:" "    \"${1}\""
        exit $?
    }
    for WIN_PLAT in $(ls "${1}" | grep 'objdir-windows'); do
        [ -d "${1}/${WIN_PLAT}" -a -d "${1}/${WIN_PLAT}/lib" ] && {
            echo "Copying ${WIN_PLAT}..."
            rm -rf "${OBJDIR_ROOT}/${WIN_PLAT}" || exit $?
            mkdir -p "${OBJDIR_ROOT}/${WIN_PLAT}" || exit $?
            cp -r "${1}/${WIN_PLAT}/lib" "${OBJDIR_ROOT}/${WIN_PLAT}/lib" || exit $?
            cp -r "${1}/${WIN_PLAT}/include" "${OBJDIR_ROOT}/${WIN_PLAT}/include" || exit $?
        } || {
            print_usage "Invalid build target:" "    \"${1}\""
            exit $?
        }
    done
}

do_combine_headers() {
    # Combine the headers into a top-level location
    COMBINED_HEADERS="${OBJDIR_ROOT}/include"
    rm -rf "${COMBINED_HEADERS}"
    mkdir -p "${COMBINED_HEADERS}" || return $?

    COMBINED_PLATS="${PKG_COMBINED_PLATS}"
    [ -n "${COMBINED_PLATS}" ] || {
        # list_plats last, so we get the right line endings
        COMBINED_PLATS="windows.i386 windows.x86_64 $(list_plats)"
    }
    for p in ${COMBINED_PLATS}; do
        _P_INC="${OBJDIR_ROOT}/objdir-${p}/include"
        if [ -d "${_P_INC}" ]; then
            cp -r "${_P_INC}/"* ${COMBINED_HEADERS} || return $?
        else
            echo "Platform ${p} has not been built"
            return 1
        fi
    done
}

do_package() {
    [ -d "${1}" ] || {
        print_usage "Invalid package output directory:" "    \"${1}\""
        exit $?
    }
    
    # Combine the headers (checks that everything is already built)
    do_combine_headers || return $?
    
    # Build the tarball
    BASE="zeromq-$(grep '^Version:' "${PATH_TO_LIBZMQ_DIST}/packaging/redhat/zeromq.spec" | \
                   cut -d':' -f2 | sed -e 's/ *//g')"
    cp -r "${OBJDIR_ROOT}" "${BASE}" || exit $?
    rm -rf "${BASE}/"*"/build" "${BASE}/logs" || exit $?
    find "${BASE}" -name .DS_Store -exec rm {} \; || exit $?
    tar -zcvpf "${1}/${BASE}.tar.gz" "${BASE}" || exit $?
    rm -rf "${BASE}"
}

# Calculate the path to the binding repositories
if [ -d "${1}" -a -f "${1}/src/libzmq.vers" ]; then
    cd "${1}"
    PATH_TO_LIBZMQ_DIST="$(pwd)"
    cd ->/dev/null
    shift 1
else
    PATH_TO_LIBZMQ_DIST="${DEFAULT_LIBZMQ_DIST}"
fi
[ -d "${PATH_TO_LIBZMQ_DIST}" -a -f "${PATH_TO_LIBZMQ_DIST}/src/libzmq.vers" ] || {
    print_usage "Invalid LibZMQ directory:" "    \"${PATH_TO_LIBZMQ_DIST}\""
    exit $?
}

if [ -d "${1}" -a -f "${1}/zmq.hpp" ]; then
    cd "${1}"
    PATH_TO_CPPZMQ_DIST="$(pwd)"
    cd ->/dev/null
    shift 1
else
    PATH_TO_CPPZMQ_DIST="${DEFAULT_CPPZMQ_DIST}"
fi
[ -d "${PATH_TO_CPPZMQ_DIST}" -a -f "${PATH_TO_CPPZMQ_DIST}/zmq.hpp" ] || {
    print_usage "Invalid cppzmq directory:" "    \"${PATH_TO_CPPZMQ_DIST}\""
    exit $?
}

if [ -d "${1}" -a -f "${1}/include/zmqcpp.h" ]; then
    cd "${1}"
    PATH_TO_ZMQCPP_DIST="$(pwd)"
    cd ->/dev/null
    shift 1
else
    PATH_TO_ZMQCPP_DIST="${DEFAULT_ZMQCPP_DIST}"
fi
[ -d "${PATH_TO_ZMQCPP_DIST}" -a -f "${PATH_TO_ZMQCPP_DIST}/include/zmqcpp.h" ] || {
    print_usage "Invalid zmqcpp directory:" "    \"${PATH_TO_ZMQCPP_DIST}\""
    exit $?
}

if [ -d "${1}" -a -f "${1}/azmq/socket.hpp" ]; then
    cd "${1}"
    PATH_TO_AZMQ_DIST="$(pwd)"
    cd ->/dev/null
    shift 1
else
    PATH_TO_AZMQ_DIST="${DEFAULT_AZMQ_DIST}"
fi
[ -d "${PATH_TO_AZMQ_DIST}" -a -f "${PATH_TO_AZMQ_DIST}/azmq/socket.hpp" ] || {
    print_usage "Invalid azmq directory:" "    \"${PATH_TO_AZMQ_DIST}\""
    exit $?
}


# Call bootstrap if that's what we specified
if [ "${1}" == "bootstrap" ]; then
    do_bootstrap ${2}
    exit $?
fi

# Call the appropriate function based on target
TARGET="${1}"; shift
case "${TARGET}" in
    "clean")
        do_clean "$@"
        ;;
    "copy-windows")
        do_copy_windows "$@"
        ;;
    "package")
        do_package "$@"
        ;;
    *)
        do_build ${TARGET} "$@"
        ;;
esac
exit $?
