#!/usr/bin/env bash

set -euo pipefail

version="${LLVM_VERSION:-20}"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  ca-certificates wget lsb-release gnupg software-properties-common

wget -q https://apt.llvm.org/llvm.sh -O /tmp/llvm.sh
chmod +x /tmp/llvm.sh
sudo /tmp/llvm.sh "${version}"

sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  "clang-${version}" \
  "clang-format-${version}" \
  "clang-tidy-${version}" \
  "llvm-${version}" \
  "lld-${version}" \
  "libclang-rt-${version}-dev" \
  "libc++-${version}-dev" \
  "libc++abi-${version}-dev"

sudo ln -f -s "$(command -v clang-${version})" /usr/local/bin/clang
sudo ln -f -s "$(command -v clang++-${version})" /usr/local/bin/clang++
sudo ln -f -s "$(command -v clang-${version})" /usr/local/bin/cc
sudo ln -f -s "$(command -v clang++-${version})" /usr/local/bin/c++
sudo ln -f -s "$(command -v ld.lld-${version})" /usr/local/bin/ld.lld

clang --version
clang++ --version
