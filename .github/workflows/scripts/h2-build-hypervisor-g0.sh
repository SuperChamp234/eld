#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: h2-build-hypervisor-g0.sh

Build Hexagon Hypervisor v68/G0 with picolibc support.

Environment:
  TOOLCHAIN_DIR         Installed LLVM/ELD toolchain root. Required.
  H2_DIR                hexagon-hypervisor source directory. Required.
  H2_INSTALL_DIR        H2 install directory. Required.
  QEMU_SYSTEM_HEXAGON   qemu-system-hexagon executable. Required.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${TOOLCHAIN_DIR:?TOOLCHAIN_DIR is required}"
: "${H2_DIR:?H2_DIR is required}"
: "${H2_INSTALL_DIR:?H2_INSTALL_DIR is required}"
: "${QEMU_SYSTEM_HEXAGON:?QEMU_SYSTEM_HEXAGON is required}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
h2_script="${H2_DIR}/scripts/build-v68-picolibc.sh"

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"
export QEMU_SYSTEM_HEXAGON
export INSTALL_PATH="${H2_INSTALL_DIR}"

if [[ -x "${h2_script}" ]]; then
  "${h2_script}" \
    RUN="${script_dir}/h2-run-hexagon-kernel.sh" \
    JFLAG="-j${H2_JOBS:-$(nproc)}"
else
  pushd "${H2_DIR}" >/dev/null
  make \
    USE_PKW=0 \
    ARCHV=68 \
    TARGET=opt \
    INSTALLPATH="${INSTALL_PATH}" \
    PICOLIBC=1 \
    RUN="${script_dir}/h2-run-hexagon-kernel.sh" \
    JFLAG="-j${H2_JOBS:-$(nproc)}"
  popd >/dev/null
fi

echo "Installed H2 into ${H2_INSTALL_DIR}"
