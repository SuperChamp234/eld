FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates clang cmake git libc++-dev libc++abi-dev llvm make meson ninja-build \
    pkg-config python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src
ENTRYPOINT ["/src/scripts/build-pico-sdk.sh"]
