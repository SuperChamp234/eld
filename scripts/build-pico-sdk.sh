#!/usr/bin/env bash
# Build pico-sdk with ELD. This is intentionally independent of GitHub Actions.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ELD_SOURCE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

LLVM_REPOSITORY="${LLVM_REPOSITORY:-https://github.com/llvm/llvm-project.git}"
LLVM_REVISION="${LLVM_REVISION:-c39c86e30d46825eecbe5908a3c73153b1aa8284}"
PICOLIBC_REPOSITORY="${PICOLIBC_REPOSITORY:-https://github.com/picolibc/picolibc.git}"
PICOLIBC_REVISION="${PICOLIBC_REVISION:-003f3e68067ba71814c0faf0936fa0c93fadd561}"
PICO_SDK_REPOSITORY="${PICO_SDK_REPOSITORY:-https://github.com/raspberrypi/pico-sdk.git}"
PICO_SDK_REVISION="${PICO_SDK_REVISION:-a1438dff1d38bd9c65dbd693f0e5db4b9ae91779}"
ARCH=""
WORK_DIR="${PWD}/pico-sdk-build"
JOBS="$(getconf _NPROCESSORS_ONLN)"
TOOLCHAIN_DIR=""

usage() {
  cat <<'EOF'
Usage: scripts/build-pico-sdk.sh --arch <rp2040|rp2350-arm|rp2350-riscv|all> [options]

Options:
  --work-dir DIR  Directory for source checkouts and build products.
  --jobs N        Parallel build jobs (default: available CPUs).
  --toolchain DIR Use an existing installed LLVM/ELD toolchain instead of building one.
  --help          Show this help.

Set LLVM_REVISION, PICOLIBC_REVISION, or PICO_SDK_REVISION to test a different
immutable upstream revision. Artifact ELFs are written to WORK_DIR/artifacts.
EOF
}

while (($#)); do
  case "$1" in
    --arch) ARCH="$2"; shift 2 ;;
    --work-dir) WORK_DIR="$2"; shift 2 ;;
    --jobs) JOBS="$2"; shift 2 ;;
    --toolchain) TOOLCHAIN_DIR="$2"; shift 2 ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "${ARCH}" ]] || { usage >&2; exit 2; }
[[ "${JOBS}" =~ ^[1-9][0-9]*$ ]] || { echo "--jobs must be positive" >&2; exit 2; }
if [[ -n "${TOOLCHAIN_DIR}" ]]; then
  TOOLCHAIN_DIR="$(cd "${TOOLCHAIN_DIR}" && pwd)"
  [[ -x "${TOOLCHAIN_DIR}/bin/clang" && -x "${TOOLCHAIN_DIR}/bin/ld.eld" ]] || {
    echo "--toolchain must contain bin/clang and bin/ld.eld" >&2
    exit 2
  }
  if [[ -r "${TOOLCHAIN_DIR}/LLVM_REVISION" ]]; then
    read -r LLVM_REVISION < "${TOOLCHAIN_DIR}/LLVM_REVISION"
    [[ "${LLVM_REVISION}" =~ ^[0-9a-f]{40}$ ]] || {
      echo "Invalid LLVM_REVISION in ${TOOLCHAIN_DIR}" >&2
      exit 2
    }
  fi
fi

for tool in git cmake ninja meson clang clang++; do
  command -v "${tool}" >/dev/null || { echo "Missing required tool: ${tool}" >&2; exit 1; }
done

clone_at() {
  local repository="$1" revision="$2" destination="$3"
  git clone --no-checkout --filter=blob:none "${repository}" "${destination}"
  git -C "${destination}" checkout --detach "${revision}"
}

configure_arch() {
  case "$1" in
    rp2040)
      PLATFORM=rp2040; TRIPLE=armv6m-none-eabi; LLVM_TARGET=ARM
      PICOLIBC_ARCH=clang-thumbv6m-rp2040; TOOLCHAIN=pico_arm_cortex_m0plus_clang.cmake
      TARGET_FLAGS="--target=${TRIPLE} -mcpu=cortex-m0plus -mthumb -mfloat-abi=soft"
      CXX_FLAGS="--target=${TRIPLE} -mfloat-abi=soft -march=armv6m"
      RUNTIME_PATH=arm-none-eabi/armv6m_soft_nofp; EXTRA_LINKER_FLAGS=""
      ;;
    rp2350-arm)
      PLATFORM=rp2350-arm-s; TRIPLE=armv8m.main-none-eabi; LLVM_TARGET=ARM
      PICOLIBC_ARCH=clang-thumbv8m.main-rp2350; TOOLCHAIN=pico_arm_cortex_m33_clang.cmake
      TARGET_FLAGS="--target=${TRIPLE} -mcpu=cortex-m33 -mthumb -mfloat-abi=softfp -march=armv8m.main+fp+dsp"
      CXX_FLAGS="-mcpu=cortex-m33 --target=${TRIPLE} -mfloat-abi=softfp -march=armv8m.main+fp+dsp"
      RUNTIME_PATH=arm-none-eabi/armv8m.main_soft_nofp; EXTRA_LINKER_FLAGS=""
      ;;
    rp2350-riscv)
      PLATFORM=rp2350-riscv; TRIPLE=riscv32-unknown-elf; LLVM_TARGET=RISCV
      PICOLIBC_ARCH=clang-rv32imac-rp2350; TOOLCHAIN=pico_riscv_clang.cmake
      TARGET_FLAGS="--target=${TRIPLE} -march=rv32imac_zicsr_zifencei_zba_zbb_zbs_zbkb -mabi=ilp32 -mno-relax"
      CXX_FLAGS="--target=${TRIPLE} -march=rv32imac_zicsr_zifencei_zba_zbb_zbs_zbkb -mabi=ilp32"
      RUNTIME_PATH=riscv32-unknown-elf; EXTRA_LINKER_FLAGS=-nostartfiles
      ;;
    *) echo "Unsupported architecture: $1" >&2; exit 2 ;;
  esac
}

build_arch() {
  local name="$1" prefix picolibc_install sysroot runtime_link pico_build
  configure_arch "${name}"
  prefix="${TOOLCHAIN_DIR:-${WORK_DIR}/install-${name}-toolchain}"
  picolibc_install="${WORK_DIR}/install-${name}-picolibc"
  sysroot="${picolibc_install}/picolibc/${TRIPLE}"
  runtime_link="${prefix}/lib/clang-runtimes/${RUNTIME_PATH}"
  pico_build="${WORK_DIR}/build-${name}-pico-sdk"

  if [[ -z "${TOOLCHAIN_DIR}" ]]; then
    cmake -G Ninja -S "${WORK_DIR}/llvm-project/llvm" -B "${WORK_DIR}/build-${name}-toolchain" \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON \
      -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_CXX_FLAGS=-stdlib=libc++ \
      -DLLVM_ENABLE_PROJECTS=clang -DLLVM_EXTERNAL_PROJECTS=eld -DLLVM_EXTERNAL_ELD_SOURCE_DIR="${ELD_SOURCE_DIR}" \
      -DLLVM_DEFAULT_TARGET_TRIPLE="${TRIPLE}" -DLLVM_TARGETS_TO_BUILD="X86;${LLVM_TARGET}" \
      -DELD_TARGETS_TO_BUILD="${LLVM_TARGET}" -DLLVM_BUILD_TESTS=OFF -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_BUILD_EXAMPLES=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_BUILD_DOCS=OFF -DLLVM_INCLUDE_DOCS=OFF \
      -DLLVM_ENABLE_ASSERTIONS=OFF -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF \
      -DLLVM_ENABLE_TERMINFO=OFF -DCMAKE_INSTALL_PREFIX="${prefix}"
    cmake --build "${WORK_DIR}/build-${name}-toolchain" --target install --parallel "${JOBS}"
  fi

  cmake -G Ninja -S "${WORK_DIR}/llvm-project/compiler-rt" -B "${WORK_DIR}/build-${TRIPLE}-builtins" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER="${prefix}/bin/clang" -DCMAKE_CXX_COMPILER="${prefix}/bin/clang++" \
    -DCMAKE_C_COMPILER_TARGET="${TRIPLE}" -DCMAKE_C_COMPILER_FORCED=ON -DCMAKE_CXX_COMPILER_FORCED=ON \
    -DCMAKE_CROSSCOMPILING=ON -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_C_FLAGS="${TARGET_FLAGS} -ffreestanding" -DCMAKE_CXX_FLAGS="${TARGET_FLAGS} -ffreestanding" \
    -DCMAKE_ASM_FLAGS="${TARGET_FLAGS}" -DCMAKE_AR="${prefix}/bin/llvm-ar" -DCMAKE_NM="${prefix}/bin/llvm-nm" \
    -DCMAKE_RANLIB="${prefix}/bin/llvm-ranlib" -DLLVM_CMAKE_DIR="${prefix}/lib/cmake/llvm" \
    -DCOMPILER_RT_BAREMETAL_BUILD=ON -DCOMPILER_RT_BUILD_BUILTINS=ON -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
    -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=ON \
    -DCMAKE_INSTALL_PREFIX="$("${prefix}/bin/clang" -print-resource-dir)"
  cmake --build "${WORK_DIR}/build-${TRIPLE}-builtins" --target install-builtins --parallel "${JOBS}"

  sed "s|@TOOLCHAIN_BIN@|${prefix}/bin|g" \
    "${ELD_SOURCE_DIR}/.github/workflows/patches/cross-${PICOLIBC_ARCH}.txt.in" \
    > "${WORK_DIR}/cross-${PICOLIBC_ARCH}.txt"
  PATH="${prefix}/bin:${PATH}" CC_LD=eld CXX_LD=eld meson setup "${WORK_DIR}/build-${name}-picolibc" "${WORK_DIR}/picolibc" \
    --cross-file "${WORK_DIR}/cross-${PICOLIBC_ARCH}.txt" --prefix "${picolibc_install}" \
    -Dc_ld=ld.eld -Dcpp_ld=ld.eld -Dincludedir="picolibc/${TRIPLE}/include" -Dlibdir="picolibc/${TRIPLE}/lib" \
    -Dspecsdir="${picolibc_install}/lib" -Dmultilib=false -Dtests=false --buildtype=minsize
  meson compile -C "${WORK_DIR}/build-${name}-picolibc" -j "${JOBS}"
  meson install -C "${WORK_DIR}/build-${name}-picolibc"

  cmake -G Ninja -S "${WORK_DIR}/llvm-project/runtimes" -B "${WORK_DIR}/build-${name}-libcxx" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER="${prefix}/bin/clang" -DCMAKE_CXX_COMPILER="${prefix}/bin/clang++" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY -DCMAKE_C_FLAGS="${TARGET_FLAGS} --sysroot=${sysroot}" \
    -DCMAKE_CXX_FLAGS="${TARGET_FLAGS} --sysroot=${sysroot} -fuse-ld=eld" -DCMAKE_AR="${prefix}/bin/llvm-ar" \
    -DCMAKE_RANLIB="${prefix}/bin/llvm-ranlib" -DCMAKE_INSTALL_PREFIX="${sysroot}" \
    -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi" -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC=ON \
    -DLIBCXX_ENABLE_FILESYSTEM=OFF -DLIBCXX_ENABLE_THREADS=OFF -DLIBCXX_ENABLE_EXCEPTIONS=OFF \
    -DLIBCXX_USE_COMPILER_RT=ON -DLIBCXXABI_ENABLE_SHARED=OFF -DLIBCXXABI_ENABLE_STATIC=ON \
    -DLIBCXXABI_ENABLE_THREADS=OFF -DLIBCXXABI_ENABLE_EXCEPTIONS=OFF -DLIBCXXABI_USE_COMPILER_RT=ON \
    -DLIBCXXABI_USE_LLVM_UNWINDER=OFF
  cmake --build "${WORK_DIR}/build-${name}-libcxx" --target install --parallel "${JOBS}"

  if [[ "${name}" == rp2350-riscv ]]; then
    cp "${ELD_SOURCE_DIR}/.github/workflows/patches/pico_riscv_clang.cmake" "${WORK_DIR}/pico-sdk/cmake/preload/toolchains/"
  fi
  mkdir -p "$(dirname "${runtime_link}")"
  ln -sfn "${sysroot}" "${runtime_link}"
  cmake -S "${WORK_DIR}/pico-sdk" -B "${pico_build}" -DCMAKE_BUILD_TYPE=Release -DPICO_PLATFORM="${PLATFORM}" \
    -DCMAKE_TOOLCHAIN_FILE="${WORK_DIR}/pico-sdk/cmake/preload/toolchains/${TOOLCHAIN}" -DPICO_TOOLCHAIN_PATH="${prefix}/bin" \
    -DPICO_CLIB=picolibc -DCMAKE_CXX_FLAGS="${CXX_FLAGS} --sysroot=${sysroot} -stdlib=libc++" \
    -DPICO_COMPILER_SYSROOT="${sysroot}" -DCMAKE_EXE_LINKER_FLAGS="${EXTRA_LINKER_FLAGS} -fuse-ld=${prefix}/bin/ld.eld --rtlib=compiler-rt -stdlib=libc++ -Wl,--sysroot="
  cmake --build "${pico_build}" --parallel "${JOBS}"
  mkdir -p "${WORK_DIR}/artifacts/${name}"
  (
    cd "${pico_build}"
    find . -type f -name '*.elf' -exec cp --parents {} "${WORK_DIR}/artifacts/${name}" \;
  )
  find "${WORK_DIR}/artifacts/${name}" -type f -name '*.elf' -print -quit | grep -q . || { echo "No ELF artifacts for ${name}" >&2; exit 1; }
}

mkdir -p "${WORK_DIR}"
clone_at "${LLVM_REPOSITORY}" "${LLVM_REVISION}" "${WORK_DIR}/llvm-project"
clone_at "${PICOLIBC_REPOSITORY}" "${PICOLIBC_REVISION}" "${WORK_DIR}/picolibc"
clone_at "${PICO_SDK_REPOSITORY}" "${PICO_SDK_REVISION}" "${WORK_DIR}/pico-sdk"
git -C "${WORK_DIR}/pico-sdk" submodule update --init --recursive
git -C "${WORK_DIR}/pico-sdk" apply --whitespace=nowarn "${ELD_SOURCE_DIR}/.github/workflows/patches/pico-sdk-eld.patch"

case "${ARCH}" in
  all) for arch in rp2040 rp2350-arm rp2350-riscv; do build_arch "${arch}"; done ;;
  rp2040|rp2350-arm|rp2350-riscv) build_arch "${ARCH}" ;;
  *) echo "Unsupported architecture: ${ARCH}" >&2; exit 2 ;;
esac
