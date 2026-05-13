# Build, test, inspect

All build & test commands. Container internals live in `docker/README.md`.


## Prerequisites

- Docker 24+ with BuildKit.
- Build the container image once:

  ```bash
  make -C docker image
  ```

  First time: ~10–20 min (pulls Ubuntu base, builds NCS workspace, installs
  Zephyr SDK). Cached after — subsequent invocations are seconds.


## Build the firmware

```bash
# nRF5340-DK, application core
make -C docker build BOARD=nrf5340dk/nrf5340/cpuapp APP=app

# nRF54LM20-DK, application core
make -C docker build BOARD=nrf54lm20pdk/nrf54lm20a/cpuapp APP=app
```

Verify the exact board string for nRF54LM20 against the pinned NCS version:

```bash
docker run --rm zephyr_ncs_bundle:3.3.0-1.0 west boards | grep -i 54l
```

Typical first build (cold ccache): ~25 s. Repeat builds: under 5 s with ccache.


### Build outputs

```
artifacts/<board_sanitized>/
├── merged.hex          Final flashable image (sysbuild-merged).
├── partitions.yml      Flash partition layout.
├── domains.yaml        Multi-domain (cpuapp/cpunet) layout.
├── .config             Sysbuild top-level Kconfig.
└── app/
    ├── zephyr.hex      Application image only (pre-merge).
    ├── zephyr.bin
    ├── zephyr.elf      With debug symbols — feed to gdb / nm / objdump.
    ├── zephyr.dts      Resolved device tree.
    ├── zephyr.map      Full linker map (every symbol, address, section size).
    ├── .config         Final app Kconfig.
    ├── rom_report.txt  Hierarchical ROM breakdown.
    └── ram_report.txt  Hierarchical RAM breakdown.
```

Flash `merged.hex` to the DK over the on-board J-Link (host-side, outside
this repo — the container is build-only).


## Run unit tests

Tests under `tests/` mirror `src/`. The top-level `tests/CMakeLists.txt`
aggregates leaves via `ExternalProject_Add`. Each leaf is a Zephyr
`COMPONENTS unittest` build — host-compiled x86 ELF, no kernel, no board.

Using ztest keeps the door open for future on-target test execution via
Zephyr's twister.

```bash
make -C docker test                       # configure + build + run all leaves
```

Output:

```
artifacts/tests/ztest_<area>_<module>/
├── ztest_<area>_<module>    Stand-alone x86 ELF (gdb / valgrind / asan friendly).
└── output.txt               Captured ztest stdout (PASS/FAIL summary, durations).
```

Run a single test binary directly on the host:

```bash
./artifacts/tests/ztest_common_greet/ztest_common_greet
```


### Add a new module and its tests

1. Create the module under `src/<area>/<module>/<module>.{h,c}`.
2. If the firmware uses it, add the `.c` to `app/CMakeLists.txt` `target_sources`.
3. Create `tests/<area>/<module>/{CMakeLists.txt, prj.conf, src/test_*.c}`
   mirroring `tests/common/greet/`.
4. `make -C docker test` — the aggregator discovers the new leaf
   automatically via `file(GLOB_RECURSE CONFIGURE_DEPENDS)`.


## Inspect / debug inside the container

```bash
make -C docker shell                                          # interactive bash

docker run --rm zephyr_ncs_bundle:3.3.0-1.0 west list         # NCS workspace state

docker run --rm zephyr_ncs_bundle:3.3.0-1.0 \
    /opt/zephyr-sdk/arm-zephyr-eabi/bin/arm-zephyr-eabi-nm \
    /workdir/artifacts/nrf5340dk_nrf5340_cpuapp/app/zephyr.elf
```


## Clean

```bash
make -C docker clean        # removes artifacts/ and any local build/
```
