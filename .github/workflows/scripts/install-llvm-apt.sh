#!/usr/bin/env bash

set -euo pipefail

version="${LLVM_VERSION:-20}"

# Support running as root (no sudo available) or as a regular user
if [[ "$(id -u)" == "0" ]]; then
  SUDO=""
else
  SUDO="sudo"
fi

${SUDO} apt-get update
${SUDO} DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  ca-certificates wget lsb-release gnupg software-properties-common

wget -q https://apt.llvm.org/llvm.sh -O /tmp/llvm.sh
chmod +x /tmp/llvm.sh
${SUDO} /tmp/llvm.sh "${version}"

${SUDO} DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  "clang-${version}" \
  "clang-format-${version}" \
  "clang-tidy-${version}" \
  "llvm-${version}" \
  "lld-${version}" \
  "libclang-rt-${version}-dev" \
  "libc++-${version}-dev" \
  "libc++abi-${version}-dev"

${SUDO} ln -f -s "$(command -v clang-${version})" /usr/local/bin/clang
${SUDO} ln -f -s "$(command -v clang++-${version})" /usr/local/bin/clang++
${SUDO} ln -f -s "$(command -v clang-${version})" /usr/local/bin/cc
${SUDO} ln -f -s "$(command -v clang++-${version})" /usr/local/bin/c++
${SUDO} ln -f -s "$(command -v ld.lld-${version})" /usr/local/bin/ld.lld

clang --version
clang++ --version
