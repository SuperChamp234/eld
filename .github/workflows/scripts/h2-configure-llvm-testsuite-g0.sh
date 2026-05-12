#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: h2-configure-llvm-testsuite-g0.sh

Configure llvm-test-suite SingleSource for H2 + picolibc + v68/G0.

Environment:
  TOOLCHAIN_DIR         Installed LLVM/ELD toolchain root. Required.
  TESTSUITE_DIR         llvm-test-suite source directory. Required.
  TESTSUITE_BUILD_DIR   llvm-test-suite build directory. Required.
  QEMU_SYSTEM_HEXAGON   qemu-system-hexagon executable. Required.
  H2_TARGET_TRIPLE      Target directory name. Defaults to hexagon-unknown-h2-picolibc.
  HOST_CC               Host C compiler. Defaults to /usr/bin/clang.
  HOST_CXX              Host C++ compiler. Defaults to /usr/bin/clang++.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${TOOLCHAIN_DIR:?TOOLCHAIN_DIR is required}"
: "${TESTSUITE_DIR:?TESTSUITE_DIR is required}"
: "${TESTSUITE_BUILD_DIR:?TESTSUITE_BUILD_DIR is required}"
: "${QEMU_SYSTEM_HEXAGON:?QEMU_SYSTEM_HEXAGON is required}"

target_triple="${H2_TARGET_TRIPLE:-hexagon-unknown-h2-picolibc}"
target_root="${TOOLCHAIN_DIR}/target/${target_triple}"
target_lib_dir="${target_root}/lib/v68/G0"
booter="${target_root}/bin/v68/G0/booter"
linker_script="${target_lib_dir}/picolibc.ld"
host_cc="${HOST_CC:-clang}"
host_cxx="${HOST_CXX:-clang++}"

if [[ ! -x "${booter}" ]]; then
  echo "error: missing H2 booter: ${booter}" >&2
  exit 1
fi
if [[ ! -f "${linker_script}" ]]; then
  echo "error: missing picolibc linker script: ${linker_script}" >&2
  exit 1
fi

mkdir -p "${TESTSUITE_BUILD_DIR}"

run_under="${TESTSUITE_BUILD_DIR}/run-h2-picolibc.sh"
toolchain_file="${TESTSUITE_BUILD_DIR}/h2-picolibc-g0-toolchain.cmake"

cat >"${run_under}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec timeout "\${H2_TEST_TIMEOUT:-120}" "${QEMU_SYSTEM_HEXAGON}" -cpu v68 -kernel "${booter}" -append "--quiet 1 \$*"
EOF
chmod +x "${run_under}"

cat >"${toolchain_file}" <<EOF
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR hexagon)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

set(CMAKE_C_COMPILER "${TOOLCHAIN_DIR}/bin/hexagon-clang" CACHE FILEPATH "" FORCE)
set(CMAKE_CXX_COMPILER "${TOOLCHAIN_DIR}/bin/hexagon-clang++" CACHE FILEPATH "" FORCE)
set(CMAKE_AR "${TOOLCHAIN_DIR}/bin/hexagon-ar" CACHE FILEPATH "" FORCE)
set(CMAKE_RANLIB "${TOOLCHAIN_DIR}/bin/hexagon-ranlib" CACHE FILEPATH "" FORCE)
set(CMAKE_LINKER "${TOOLCHAIN_DIR}/bin/hexagon-link" CACHE FILEPATH "" FORCE)

set(CMAKE_C_COMPILER_TARGET hexagon-h2-picolibc CACHE STRING "" FORCE)
set(CMAKE_CXX_COMPILER_TARGET hexagon-h2-picolibc CACHE STRING "" FORCE)

set(CMAKE_C_FLAGS "-G0 -D_GNU_SOURCE" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS "-G0 -D_GNU_SOURCE" CACHE STRING "" FORCE)
set(CMAKE_EXE_LINKER_FLAGS "-G0 -T ${linker_script} -Wl,--defsym=__flash=0x02000000 -Wl,--defsym=__flash_size=0x02000000 -Wl,--defsym=__ram=0x04000000 -Wl,--defsym=__ram_size=0x04000000 -Wl,--defsym=__heap_size_min=0x100000 -Wl,--defsym=__stack_size=0x10000" CACHE STRING "" FORCE)

set(CMAKE_FIND_ROOT_PATH "${target_root}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

cmake_args=(
  -G Ninja
  -S "${TESTSUITE_DIR}"
  -B "${TESTSUITE_BUILD_DIR}"
  -DCMAKE_TOOLCHAIN_FILE="${toolchain_file}"
  -DCMAKE_BUILD_TYPE=Release
  -DTEST_SUITE_SUBDIRS=SingleSource
  -DTEST_SUITE_RUN_TYPE=train
  -DTEST_SUITE_RUN_BENCHMARKS=ON
  -DTEST_SUITE_USER_MODE_EMULATION=ON
  -DTEST_SUITE_RUN_UNDER="${run_under}"
  -DTEST_SUITE_DISABLE_PIE=ON
  -DTEST_SUITE_COLLECT_CODE_SIZE=ON
  -DTEST_SUITE_COLLECT_COMPILE_TIME=ON
  -DTEST_SUITE_LLVM_SIZE="${TOOLCHAIN_DIR}/bin/llvm-size"
  -DTEST_SUITE_HOST_CC="${host_cc}"
  -DTEST_SUITE_HOST_CXX="${host_cxx}"
  -DTEST_SUITE_LIT_FLAGS="-sv"
)

if command -v lit >/dev/null 2>&1; then
  cmake_args+=(-DTEST_SUITE_LIT="$(command -v lit)")
elif command -v llvm-lit >/dev/null 2>&1; then
  cmake_args+=(-DTEST_SUITE_LIT="$(command -v llvm-lit)")
fi

cmake "${cmake_args[@]}"

echo "Configured llvm-test-suite in ${TESTSUITE_BUILD_DIR}"
