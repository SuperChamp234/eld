#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: h2-run-picolibc-test.sh <elf> [args...]" >&2
  exit 2
fi

qemu="${QEMU_SYSTEM_HEXAGON:-$(command -v qemu-system-hexagon || true)}"
booter="${H2_BOOTER:-}"

if [[ -z "${qemu}" ]]; then
  echo "error: qemu-system-hexagon not found" >&2
  exit 1
fi
if [[ -z "${booter}" || ! -x "${booter}" ]]; then
  echo "error: H2_BOOTER must point to an executable booter" >&2
  exit 1
fi

exec timeout "${H2_TEST_TIMEOUT:-120}" \
  "${qemu}" -cpu "${HEXAGON_CPU:-v68}" -kernel "${booter}" -append "--quiet 1 $*"
