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
└── artifacts/  Build outputs (generated; gitignored).
```

## The example app

`app/` is a minimal Zephyr application that prints `greet(CONFIG_BOARD)` and a
tick counter once per second. The greet implementation lives in
`src/common/greet/` so the same code path is exercised by both the firmware
and the unit tests.

Footprint on nrf5340dk/nrf5340/cpuapp: **~34 KB flash, ~8 KB RAM**.

## Where to look next

- **`BUILD_APP.md`** — how to build the firmware, run the unit tests, inspect
  outputs.
- **`docker/README.md`** — container internals: tag scheme, build args, run
  modes, env vars, corporate TLS inspection setup.
- **`LICENSE` / `NOTICE`** — Apache-2.0 and third-party attributions.
