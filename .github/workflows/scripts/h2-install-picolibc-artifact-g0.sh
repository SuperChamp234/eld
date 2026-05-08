#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: h2-install-picolibc-artifact-g0.sh

Install a picolibc nightly artifact into the H2 v68/G0 target layout.

Environment:
  TOOLCHAIN_DIR          Installed LLVM/ELD toolchain root. Required.
  PICOLIBC_ARTIFACT_DIR  Extracted picolibc artifact root. Required.
  H2_TARGET_TRIPLE       Target directory name. Defaults to hexagon-unknown-h2-picolibc.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${TOOLCHAIN_DIR:?TOOLCHAIN_DIR is required}"
: "${PICOLIBC_ARTIFACT_DIR:?PICOLIBC_ARTIFACT_DIR is required}"

target_triple="${H2_TARGET_TRIPLE:-hexagon-unknown-h2-picolibc}"
target_root="${TOOLCHAIN_DIR}/target/${target_triple}"
target_lib_dir="${target_root}/lib/v68/G0"
target_include_dir="${target_root}/include"
resource_dir="$(${TOOLCHAIN_DIR}/bin/clang -print-resource-dir)"
builtins_dir="${resource_dir}/lib/hexagon-unknown-none-elf"

shopt -s globstar nullglob

lib_dir=""
for candidate in "${PICOLIBC_ARTIFACT_DIR}"/**/picolibc/hexagon/lib/libc.a "${PICOLIBC_ARTIFACT_DIR}"/**/libc.a; do
  lib_dir="$(dirname "${candidate}")"
  break
done

include_dir=""
for candidate in "${PICOLIBC_ARTIFACT_DIR}"/**/picolibc/hexagon/include "${PICOLIBC_ARTIFACT_DIR}"/**/include; do
  if [[ -d "${candidate}" ]]; then
    include_dir="${candidate}"
    break
  fi
done

if [[ -z "${lib_dir}" || ! -f "${lib_dir}/libc.a" ]]; then
  echo "error: could not find picolibc lib directory under ${PICOLIBC_ARTIFACT_DIR}" >&2
  exit 1
fi
if [[ -z "${include_dir}" || ! -d "${include_dir}" ]]; then
  echo "error: could not find picolibc include directory under ${PICOLIBC_ARTIFACT_DIR}" >&2
  exit 1
fi

mkdir -p "${target_lib_dir}" "${target_include_dir}"
cp -a "${lib_dir}/." "${target_lib_dir}/"
cp -a "${include_dir}/." "${target_include_dir}/"

if [[ -f "${builtins_dir}/libclang_rt.builtins.a" ]]; then
  cp "${builtins_dir}/libclang_rt.builtins.a" "${target_lib_dir}/"
fi

echo "Installed picolibc artifact from ${lib_dir} into ${target_lib_dir}"
