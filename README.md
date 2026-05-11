# zephyr (project)

Greenfield Zephyr / nRF Connect SDK firmware. Target hardware: nRF5340-DK and
nRF54LM20-DK; same code path, different `BOARD=`.

All builds run inside a pinned container (`zephyr_ncs_bundle:3.3.0-1.0`). No
host toolchain or SDK install needed beyond Docker.

## Layout

```
.
├── app/        Example application (this README's quick start).
├── docker/     Build container: Dockerfile, entrypoint, Makefile, CA certs.
│               See docker/README.md for container details.
└── artifacts/  Build outputs (generated; gitignored).
```

## Prerequisites

- Docker 24+ with BuildKit.
- The container image built once: `make -C docker image` (~10–20 min the first
  time; cached after).

## Build the example app

```bash
make -C docker build BOARD=nrf5340dk/nrf5340/cpuapp     APP=app
make -C docker build BOARD=nrf54lm20pdk/nrf54lm20a/cpuapp APP=app   # if board string differs in NCS v3.3, run: docker run --rm zephyr_ncs_bundle:3.3.0-1.0 west boards | grep -i 54l
```

Typical first build (cold ccache): ~25 s. Repeat builds: under 5 s with ccache.

## Outputs

After a build, artifacts land at `artifacts/<board_sanitized>/`:

```
artifacts/nrf5340dk_nrf5340_cpuapp/
├── merged.hex          Final flashable image (sysbuild-merged).
└── app/
    ├── zephyr.hex      Application image only (pre-merge).
    ├── zephyr.bin
    ├── zephyr.elf      With debug symbols — feed to gdb / nm / objdump.
    └── zephyr.dts      Resolved device tree.
```

Flash `merged.hex` to the DK over the on-board J-Link (outside this repo — the
container is build-only).

## The example app

`app/` is a minimal Zephyr application that prints the board name and a tick
counter once per second.

```
app/
├── CMakeLists.txt    find_package(Zephyr) + project + target_sources.
├── prj.conf          CONFIG_PRINTK=y, CONFIG_LOG=y.
└── src/main.c        main() with printk("tick %u") in a k_msleep loop.
```

Footprint on nrf5340dk/nrf5340/cpuapp: **~34 KB flash, ~8 KB RAM**. Plenty of
headroom on any of the target SoCs.

## Inspecting / debugging inside the container

```bash
make -C docker shell                                        # interactive bash
docker run --rm zephyr_ncs_bundle:3.3.0-1.0 west list       # workspace state
docker run --rm zephyr_ncs_bundle:3.3.0-1.0 \
    /opt/zephyr-sdk/arm-zephyr-eabi/bin/arm-zephyr-eabi-nm  \
    /workdir/artifacts/nrf5340dk_nrf5340_cpuapp/app/zephyr.elf
```

## Further reading

- `docker/README.md` — container internals: tag scheme, build args, the two
  run modes (bind-mount vs. ephemeral clone), env vars, corporate TLS
  inspection setup.
