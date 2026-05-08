#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: h2-run-hexagon-kernel.sh <elf> [args...]" >&2
  exit 2
fi

qemu="${QEMU_SYSTEM_HEXAGON:-$(command -v qemu-system-hexagon || true)}"
if [[ -z "${qemu}" ]]; then
  echo "error: qemu-system-hexagon not found" >&2
  exit 1
fi

elf="$1"
shift

exec "${qemu}" -cpu "${HEXAGON_CPU:-v68}" -kernel "${elf}" -append "$*"
