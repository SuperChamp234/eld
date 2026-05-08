#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: h2-build-qemu-hexagon.sh

Build qemu-system-hexagon for H2 and picolibc tests.

Environment:
  QEMU_SRC_DIR      QEMU source directory. Required.
  QEMU_INSTALL_DIR  QEMU install directory. Required.
  QEMU_REPO         QEMU repository. Defaults to https://github.com/quic/qemu.git.
  QEMU_REF          QEMU branch/ref. Defaults to hexagon-sysemu-11-nov-2025.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${QEMU_SRC_DIR:?QEMU_SRC_DIR is required}"
: "${QEMU_INSTALL_DIR:?QEMU_INSTALL_DIR is required}"

qemu_repo="${QEMU_REPO:-https://github.com/quic/qemu.git}"
qemu_ref="${QEMU_REF:-hexagon-sysemu-11-nov-2025}"

if [[ ! -x "${QEMU_INSTALL_DIR}/bin/qemu-system-hexagon" ]]; then
  if [[ ! -d "${QEMU_SRC_DIR}/.git" ]]; then
    git clone --depth 1 --branch "${qemu_ref}" "${qemu_repo}" "${QEMU_SRC_DIR}"
  fi

  pushd "${QEMU_SRC_DIR}" >/dev/null
  ./configure --target-list=hexagon-softmmu --prefix="${QEMU_INSTALL_DIR}"
  ninja -C build install
  popd >/dev/null
fi

"${QEMU_INSTALL_DIR}/bin/qemu-system-hexagon" --version
