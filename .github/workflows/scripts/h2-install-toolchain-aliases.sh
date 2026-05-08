#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: h2-install-toolchain-aliases.sh

Create hexagon-* compatibility links in an installed LLVM/ELD toolchain.

Environment:
  TOOLCHAIN_DIR   Installed toolchain root. Required.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${TOOLCHAIN_DIR:?TOOLCHAIN_DIR is required}"

bin_dir="${TOOLCHAIN_DIR}/bin"
if [[ ! -d "${bin_dir}" ]]; then
  echo "error: missing toolchain bin directory: ${bin_dir}" >&2
  exit 1
fi

link_tool() {
  local alias_name="$1"
  local target_name="$2"

  if [[ -e "${bin_dir}/${alias_name}" ]]; then
    return 0
  fi
  if [[ ! -e "${bin_dir}/${target_name}" ]]; then
    echo "warning: cannot create ${alias_name}; missing ${target_name}" >&2
    return 0
  fi

  ln -s "${target_name}" "${bin_dir}/${alias_name}"
}

link_tool hexagon-clang clang
link_tool hexagon-clang++ clang++
link_tool hexagon-ar llvm-ar
link_tool hexagon-ranlib llvm-ranlib
link_tool hexagon-nm llvm-nm
link_tool hexagon-strip llvm-strip
link_tool hexagon-addr2line llvm-addr2line
link_tool hexagon-llvm-objcopy llvm-objcopy
link_tool hexagon-llvm-objdump llvm-objdump
link_tool hexagon-llvm-readelf llvm-readelf
link_tool hexagon-link ld.eld

echo "Installed Hexagon compatibility links in ${bin_dir}"
