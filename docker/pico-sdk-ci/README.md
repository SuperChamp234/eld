# Pico SDK local CI

Build the development image from the ELD repository root:

```sh
docker build -t eld-pico-sdk-ci -f docker/pico-sdk-ci/Dockerfile .
```

Run one target with the source tree mounted read-only and retain build products
on the host:

```sh
docker run --rm -v "$PWD:/src:ro" -v "$PWD/pico-sdk-build:/work" \
  eld-pico-sdk-ci --arch rp2040 --work-dir /work
```

Use `--arch all` to exercise every target. The image is only a reproducible
host-tool environment; `scripts/build-pico-sdk.sh` clones each pinned upstream
source revision and performs the same build locally and in GitHub Actions.
