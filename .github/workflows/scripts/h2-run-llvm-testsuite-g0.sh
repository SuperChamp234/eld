#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: h2-run-llvm-testsuite-g0.sh

Build and run llvm-test-suite SingleSource tests. The build uses ninja -k 0 so
independent tests continue after individual compile/link failures.

Environment:
  TESTSUITE_BUILD_DIR  llvm-test-suite build directory. Required.
  LIT_JOBS             Number of lit jobs. Defaults to 2.
  RESULTS_JSON         Lit JSON output path. Defaults to <build>/h2-single-source-results.json.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

: "${TESTSUITE_BUILD_DIR:?TESTSUITE_BUILD_DIR is required}"

results_json="${RESULTS_JSON:-${TESTSUITE_BUILD_DIR}/h2-single-source-results.json}"
lit_jobs="${LIT_JOBS:-2}"

set +e
ninja -C "${TESTSUITE_BUILD_DIR}" -k 0
build_status=$?

if command -v lit >/dev/null 2>&1; then
  lit -sv -j"${lit_jobs}" -o "${results_json}" "${TESTSUITE_BUILD_DIR}/SingleSource"
  lit_status=$?
elif command -v llvm-lit >/dev/null 2>&1; then
  llvm-lit -sv -j"${lit_jobs}" -o "${results_json}" "${TESTSUITE_BUILD_DIR}/SingleSource"
  lit_status=$?
else
  python3 -m lit -sv -j"${lit_jobs}" -o "${results_json}" "${TESTSUITE_BUILD_DIR}/SingleSource"
  lit_status=$?
fi
set -e

if [[ ${build_status} -ne 0 ]]; then
  echo "llvm-test-suite build had failures" >&2
fi
if [[ ${lit_status} -ne 0 ]]; then
  echo "llvm-test-suite lit had failures" >&2
fi

if [[ ${build_status} -ne 0 || ${lit_status} -ne 0 ]]; then
  exit 1
fi
