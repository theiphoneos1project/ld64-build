#!/usr/bin/env bash

# Copyright (c) 2026 Nightwind

set -e

printf "\n"
printf "ld64 patcher for Objective-C 1 (fragile runtime) support\n"
printf "By NightwindDev\n"
printf "\n"

INTERACTIVE=1

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --non-interactive)
            INTERACTIVE=0
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--non-interactive]"
            printf "\n"
            exit 0
            ;;
        *)
            echo "[!] Error: Unknown parameter passed: $1"
            printf "\n"
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
if [ ! -d "${SCRIPT_DIR}/Patches" ]; then
    echo "[!] Error: This script is in an incorrect position in the filesystem. Make sure you have the Patches folder in the same directory as this script."
    echo "Expected at: ${SCRIPT_DIR}/Patches"
    exit 1
fi

if [ "$(uname)" != "Darwin" ]; then
    echo "[!] Error: This script requires macOS. Exiting..."
    exit 1
fi

if ! xcode-select -p &>/dev/null; then
    echo "[!] Xcode not found!"
    echo "In order to compile ld64, you will need Xcode to be installed. Once you have instaleld it, run this script again to continue."
    exit 1
fi

if ! xcrun clang++ -std=c++20 -x c++ - -c -o /tmp/cxx20_test.o <<< "int main() {}" 2>/dev/null; then
    echo "[!] Error: Your Xcode toolchain does not support C++20."
    exit 1
fi

rm -f /tmp/cxx20_test.o

echo "[+] Begin"

WORKING_DIR="ld64_working_dir"

if [ -d "${WORKING_DIR}" ]; then
    if [ "${INTERACTIVE}" -eq 1 ]; then 
        read -r -p "[-] Previous working directory already found. Delete and start over? (y/n): " RESPONSE
    else
        echo "[-] Non-interactive mode active. Automatically deleting old working directory for a clean build..."
        RESPONSE="y"
    fi

    RESPONSE=$(echo "${RESPONSE}" | tr '[:upper:]' '[:lower:]')
    
    if [ "${RESPONSE}" = "y" ]; then
        rm -rf "${WORKING_DIR}"
        echo "[+] Making working directory"
        mkdir "${WORKING_DIR}"
    fi

    printf "\n"
else
    echo "[+] Making working directory"
    mkdir "${WORKING_DIR}"
fi

cd "${WORKING_DIR}" || exit 1

if [ ! -d "ld64" ]; then
    echo "[+] Cloning ld64-957.1"
    git clone https://github.com/apple-oss-distributions/ld64
    git -C ld64 -c advice.detachedHead=false checkout ld64-957.1
fi

if [ ! -d "tapi-main" ]; then
    echo "[+] Fetching tapi"
    mkdir tapi-main
    curl -sSL https://github.com/apple-oss-distributions/tapi/tarball/tapi-1600.0.11.8 | tar xz -C tapi-main --strip-components=1
fi

if [ ! -d "corecrypto-main" ]; then
    echo "[+] Fetching corecrypto"
    mkdir corecrypto-main
    curl -sSL https://github.com/apple/corecrypto/tarball/2026-05 | tar xz -C corecrypto-main --strip-components=1
fi

if [ ! -d "external_includes" ]; then
    echo "[+] Fetching external headers"
    mkdir external_includes
fi

if [ ! -f "external_includes/os/lock_private.h" ]; then
    echo "[+] Fetching <os/lock_private.h>"
    mkdir -p external_includes/os
    curl -sSL https://raw.githubusercontent.com/checkra1n/ld64-build/fa8504b870f82005eda85dc7563e6799c601e8f8/include/os/lock_private.h > external_includes/os/lock_private.h
fi

if [ ! -f "external_includes/CommonCrypto/CommonDigestSPI.h" ]; then
    echo "[+] Fetching <CommonCrypto/CommonDigestSPI.h>"
    mkdir -p external_includes/CommonCrypto
    curl -sSL https://raw.githubusercontent.com/PureDarwin/CommonCrypto/refs/heads/master/Source/CommonCryptoSPI/CommonDigestSPI.h > external_includes/CommonCrypto/CommonDigestSPI.h
fi

mkdir -p external_includes/System/arm
mkdir -p external_includes/System/i386
mkdir -p external_includes/System/machine

if [ ! -f "external_includes/System/arm/cpu_capabilities.h" ]; then
    echo "[+] Fetching <System/arm/cpu_capabilities.h>"
    curl -sSL https://raw.githubusercontent.com/apple/darwin-xnu/refs/heads/main/osfmk/arm/cpu_capabilities.h > external_includes/System/arm/cpu_capabilities.h
fi

if [ ! -f "external_includes/System/i386/cpu_capabilities.h" ]; then
    echo "[+] Fetching <System/i386/cpu_capabilities.h>"
    curl -sSL https://raw.githubusercontent.com/apple/darwin-xnu/refs/heads/main/osfmk/i386/cpu_capabilities.h > external_includes/System/i386/cpu_capabilities.h
fi

if [ ! -f "external_includes/System/machine/cpu_capabilities.h" ]; then
    echo "[+] Fetching <System/machine/cpu_capabilities.h>"
    curl -sSL https://raw.githubusercontent.com/apple/darwin-xnu/refs/heads/main/osfmk/machine/cpu_capabilities.h > external_includes/System/machine/cpu_capabilities.h
fi

if [ ! -f "external_includes/llvm-c/lto.h" ]; then
    echo "[+] Fetching <llvm-c/lto.h>"
    mkdir -p external_includes/llvm-c
    curl -sSL https://raw.githubusercontent.com/llvm/llvm-project/llvmorg-7.0.1/llvm/include/llvm-c/lto.h > external_includes/llvm-c/lto.h
fi

if [ ! -f "external_includes/mach-o/dyld_priv.h" ]; then
    echo "[+] Fetching <mach-o/dyld_priv.h>"
    mkdir -p external_includes/mach-o
    curl -sSL https://raw.githubusercontent.com/apple-opensource/dyld/852.2/include/mach-o/dyld_priv.h > external_includes/mach-o/dyld_priv.h
fi

echo "[+] Starting patches"
if [ ! -f "tapi-main/include/tapi/Version.inc" ]; then
    echo "[+] Copying Version.inc to tapi-main/include/tapi/Version.inc"
    cp "${SCRIPT_DIR}/Patches/Version.inc" "tapi-main/include/tapi/Version.inc"
fi

apply_patch_if_needed() {
    local FILE_PATH="${1}"
    local PATCH_PATH="${2}"

    local FILE_NAME=$(basename "${FILE_PATH}")

    if patch -s -f -R --dry-run "${FILE_PATH}" < "${PATCH_PATH}" > /dev/null 2>&1; then
        echo "[-] ${FILE_NAME} already patched, skipping..."
    else
        echo "[+] Patching ${FILE_NAME}..."
        patch -s -f "${FILE_PATH}" < "${PATCH_PATH}"
    fi
}

apply_patch_if_needed "external_includes/mach-o/dyld_priv.h" "${SCRIPT_DIR}/Patches/dyld_priv.h.patch"
apply_patch_if_needed "ld64/src/ld/parsers/lto_file.cpp" "${SCRIPT_DIR}/Patches/lto_file.cpp.patch"
apply_patch_if_needed "ld64/src/ld/parsers/macho_relocatable_file.cpp" "${SCRIPT_DIR}/Patches/macho_relocatable_file.cpp.patch"
apply_patch_if_needed "ld64/src/ld/Options.cpp" "${SCRIPT_DIR}/Patches/Options.cpp.patch"
apply_patch_if_needed "ld64/src/ld/OutputFile.cpp" "${SCRIPT_DIR}/Patches/OutputFile.cpp.patch"

echo "[+] Building ld64!"

MACOS_SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
echo "[+] macOS SDK set to: ${MACOS_SDK_PATH}"

cd ld64

if [ -d "build" ]; then
    rm -rf "build"
fi

TAPI_LIB_PATH="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib"
ARCH_FLAGS="-arch arm64"

if lipo -archs "${TAPI_LIB_PATH}/libtapi.dylib" 2>/dev/null | grep -q "x86_64"; then
    echo "[+] Universal libtapi found, building for arm64 and x86_64"
    ARCH_FLAGS="-arch arm64 -arch x86_64"
else
    echo "[-] No universal libtapi found, building arm64 only"
fi

# Bumping the deployment target is necessary since Xcode 27 drops support for older versions
XCODE_VERSION=$(xcodebuild -version | head -1 | awk '{print $2}' | cut -d. -f1)
DEPLOYMENT_TARGET_FLAGS=""
if [ "${XCODE_VERSION}" -ge 27 ]; then
    echo "[+] Xcode 27 is present, bumping deployment target to macOS 12.0 Monterey"
    DEPLOYMENT_TARGET_FLAGS="MACOSX_DEPLOYMENT_TARGET=12.0"
fi

xcodebuild\
    -target ld\
    -configuration Release\
    SDKROOT="${MACOS_SDK_PATH}"\
    ${ARCH_FLAGS}\
    ${DEPLOYMENT_TARGET_FLAGS}\
    -quiet\
    GCC_WARN_INHIBIT_ALL_WARNINGS=YES\
    CLANG_CXX_LANGUAGE_STANDARD=c++20\
    HEADER_SEARCH_PATHS='$(SRCROOT)/../tapi-main/include $(SRCROOT)/../corecrypto-main/cc $(SRCROOT)/../corecrypto-main/ccdigest $(SRCROOT)/../corecrypto-main/ccn $(SRCROOT)/../corecrypto-main/ccsha1 $(SRCROOT)/../corecrypto-main/ccsha2 $(SRCROOT)/../external_includes $(inherited)'\
    LIBRARY_SEARCH_PATHS="${TAPI_LIB_PATH}"' $(inherited)'
cd ../..

mv "${WORKING_DIR}/ld64/build/Release/ld-classic" "$(pwd)/ld64-objc1"

printf "\n"
printf "[+] Done! Your ld should be at $(pwd)/ld64-objc1\n"
printf "\n"