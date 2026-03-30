#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CORE_DIR="${ROOT_DIR}/core"
SWIFT_DIR="${ROOT_DIR}/swift"
OUT_DIR="${SWIFT_DIR}/.build-moonshine-xcframework"
XCFRAMEWORK_OUT="${SWIFT_DIR}/Moonshine.xcframework"

ARM64_BUILD="${OUT_DIR}/build-arm64"
X86_64_BUILD="${OUT_DIR}/build-x86_64"
MACOS_DEPLOYMENT_TARGET="13.0"

rm -rf "${OUT_DIR}"
mkdir -p "${ARM64_BUILD}" "${X86_64_BUILD}"

build_one() {
  local arch="$1"
  local build_dir="$2"

  cmake -S "${CORE_DIR}" -B "${build_dir}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET}" \
    -DCMAKE_OSX_ARCHITECTURES="${arch}" \
    -DMOONSHINE_BUILD_SWIFT=ON \
    -DMOONSHINE_BUILD_SHARED=OFF

  cmake --build "${build_dir}" --target moonshine
}

build_one "arm64" "${ARM64_BUILD}"
build_one "x86_64" "${X86_64_BUILD}"

ARM64_FRAMEWORK="$(find "${ARM64_BUILD}" -type d -name "moonshine.framework" -maxdepth 4 | head -n 1)"
X86_64_FRAMEWORK="$(find "${X86_64_BUILD}" -type d -name "moonshine.framework" -maxdepth 4 | head -n 1)"

if [[ -z "${ARM64_FRAMEWORK}" || -z "${X86_64_FRAMEWORK}" ]]; then
  echo "Could not find moonshine.framework outputs."
  echo "arm64: ${ARM64_FRAMEWORK}"
  echo "x86_64: ${X86_64_FRAMEWORK}"
  exit 1
fi

rm -rf "${XCFRAMEWORK_OUT}"

ARM64_BIN="${ARM64_FRAMEWORK}/moonshine"
X86_64_BIN="${X86_64_FRAMEWORK}/moonshine"

if [[ ! -f "${ARM64_BIN}" || ! -f "${X86_64_BIN}" ]]; then
  echo "Could not find framework binaries."
  echo "arm64 binary: ${ARM64_BIN}"
  echo "x86_64 binary: ${X86_64_BIN}"
  exit 1
fi

normalize_archs() {
  # Normalize order/spacing from `lipo -info` output for robust comparison.
  echo "$1" | xargs -n1 | sort | xargs
}

ARM64_ARCHS_RAW="$(lipo -info "${ARM64_BIN}" | sed 's/.*are: //')"
X86_64_ARCHS_RAW="$(lipo -info "${X86_64_BIN}" | sed 's/.*are: //')"
ARM64_ARCHS="$(normalize_archs "${ARM64_ARCHS_RAW}")"
X86_64_ARCHS="$(normalize_archs "${X86_64_ARCHS_RAW}")"

echo "arm64 build framework archs: ${ARM64_ARCHS_RAW}"
echo "x86_64 build framework archs: ${X86_64_ARCHS_RAW}"

ensure_modulemap() {
  local framework_dir="$1"
  local versioned_dir="${framework_dir}/Versions/A"
  local headers_dir="${versioned_dir}/Headers"
  local modules_dir="${versioned_dir}/Modules"
  local modulemap_path="${modules_dir}/module.modulemap"

  mkdir -p "${modules_dir}"
  cat > "${modulemap_path}" <<'EOF'
framework module Moonshine {
  umbrella header "moonshine-c-api.h"
  export *
  module * { export * }
}
EOF

  if [[ ! -e "${framework_dir}/Headers" ]]; then
    ln -s Versions/Current/Headers "${framework_dir}/Headers"
  fi
  if [[ ! -e "${framework_dir}/Modules" ]]; then
    ln -s Versions/Current/Modules "${framework_dir}/Modules"
  fi
}

ensure_modulemap "${ARM64_FRAMEWORK}"
ensure_modulemap "${X86_64_FRAMEWORK}"

# Some CMake/Xcode toolchain combinations emit a universal binary in both
# build directories, but with only one "good" slice per output.
# To guarantee a valid universal macOS framework, stitch slices explicitly:
# - arm64 from the arm64 build
# - x86_64 from the x86_64 build
FIXED_FRAMEWORK="${OUT_DIR}/moonshine.framework"
rm -rf "${FIXED_FRAMEWORK}"
cp -R "${ARM64_FRAMEWORK}" "${FIXED_FRAMEWORK}"

lipo -thin arm64 "${ARM64_BIN}" -output "${OUT_DIR}/moonshine.arm64"
lipo -thin x86_64 "${X86_64_BIN}" -output "${OUT_DIR}/moonshine.x86_64"
lipo -create "${OUT_DIR}/moonshine.arm64" "${OUT_DIR}/moonshine.x86_64" \
  -output "${FIXED_FRAMEWORK}/moonshine"

if [[ -d "${FIXED_FRAMEWORK}/Versions/A" ]]; then
  cp "${FIXED_FRAMEWORK}/moonshine" "${FIXED_FRAMEWORK}/Versions/A/moonshine"
fi

ensure_modulemap "${FIXED_FRAMEWORK}"

xcodebuild -create-xcframework \
  -framework "${FIXED_FRAMEWORK}" \
  -output "${XCFRAMEWORK_OUT}"

echo "Wrote ${XCFRAMEWORK_OUT}"

