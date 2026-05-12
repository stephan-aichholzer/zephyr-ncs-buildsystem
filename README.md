# zephyr (project)

Greenfield Zephyr / nRF Connect SDK firmware. Target hardware: nRF5340-DK and
nRF54LM20-DK; same code path, different `BOARD=`.

All builds run inside a pinned container (`zephyr_ncs_bundle:3.3.0-1.0`). No
host toolchain or SDK install needed beyond Docker.

## Layout

```
.
├── app/        Example application — uses the greet module from src/common.
├── src/        Reusable common modules. Today: src/common/greet/.
├── tests/      Host-compiled unit tests, one CMake project per module.
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

`app/` is a minimal Zephyr application that prints `greet(CONFIG_BOARD)` and a
tick counter once per second. The greet implementation lives in
`src/common/greet/` so the same code path is exercised by both the firmware
and the unit tests.

Footprint on nrf5340dk/nrf5340/cpuapp: **~34 KB flash, ~8 KB RAM**.

## Run unit tests

`tests/` mirrors `src/`. A top-level `tests/CMakeLists.txt` uses
`ExternalProject_Add` to wrap each leaf test as its own isolated Zephyr
unittest build. Result: one executable per module, named `ztest_<area>_<module>`.

```bash
make -C docker test                              # configure + build + run all
```

Each test produces a stand-alone x86 Linux ELF (no kernel, no board — gdb /
valgrind / asan friendly). Per-test outputs land at `artifacts/tests/<name>/`:

```
artifacts/tests/ztest_common_greet/
├── ztest_common_greet    The compiled x86 test executable.
└── output.txt            Captured ztest stdout (PASS/FAIL summary, durations).
```

Adding a new test:

1. Create the module under `src/<area>/<module>/`.
2. Create `tests/<area>/<module>/{CMakeLists.txt, prj.conf, src/test_*.c}`
   mirroring `tests/common/greet/`.
3. `make -C docker test` — the aggregator discovers it automatically via
   `file(GLOB_RECURSE CONFIGURE_DEPENDS)`.

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
