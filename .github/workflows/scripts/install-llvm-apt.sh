#!/usr/bin/env bash

set -euo pipefail

# Support running as root (no sudo available) or as a regular user
if [[ "$(id -u)" == "0" ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

export DEBIAN_FRONTEND=noninteractive

${SUDO} apt-get update
${SUDO} apt-get install -yq --no-install-recommends \
  clang \
  clang-format \
  clang-tidy \
  llvm \
  lld \
  libclang-rt-dev \
  libc++-dev \
  libc++abi-dev

clang --version
clang++ --version
