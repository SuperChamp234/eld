#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: h2-install-hypervisor-into-toolchain-g0.sh

Install H2 libraries, headers, and booter into a v68/G0 H2 picolibc target layout.

Environment:
  TOOLCHAIN_DIR      Installed LLVM/ELD toolchain root. Required.
  H2_INSTALL_DIR     H2 install directory. Required.
  H2_TARGET_TRIPLE   Target directory name. Defaults to hexagon-unknown-h2-picolibc.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${TOOLCHAIN_DIR:?TOOLCHAIN_DIR is required}"
: "${H2_INSTALL_DIR:?H2_INSTALL_DIR is required}"

target_triple="${H2_TARGET_TRIPLE:-hexagon-unknown-h2-picolibc}"
target_root="${TOOLCHAIN_DIR}/target/${target_triple}"
target_lib_dir="${target_root}/lib/v68/G0"
target_bin_dir="${target_root}/bin/v68/G0"

mkdir -p "${target_lib_dir}" "${target_bin_dir}" "${target_root}/include"

cp "${H2_INSTALL_DIR}/lib/"*.a "${target_lib_dir}/"
cp -a "${H2_INSTALL_DIR}/include/." "${target_root}/include/"
cp "${H2_INSTALL_DIR}/bin/booter" "${target_bin_dir}/booter"

echo "Installed H2 v68/G0 files into ${target_root}"
