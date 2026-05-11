# zephyr_ncs_bundle (container)

Self-contained Docker build container for Zephyr / nRF Connect SDK firmware.
One image, both nRF53 and nRF54 targets. Same image used locally and in CI.
Offline at runtime — the NCS workspace and toolchain are baked in.

> Building the project's example app? See `../README.md`. This file documents
> the **container itself** — how it's built, how it accepts work, what's inside.

## What's locked in this build

| Component        | Version                                            |
|------------------|----------------------------------------------------|
| NCS              | v3.3.0                                             |
| Zephyr           | 4.3.99 (Nordic's sdk-zephyr fork, tag `ncs-v3.3.0`)|
| Zephyr SDK       | 0.17.4 (arm-zephyr-eabi-gcc 12.2.0)                |
| west             | 1.2.0                                              |
| JFrog CLI (`jf`) | 2.103.0                                            |
| Base             | Ubuntu 24.04                                       |
| Image size       | ~2.6 GB                                            |

Build tools: `cmake`, `ninja`, `gperf`, `ccache`, `dtc`, `dfu-util`, `make`,
host `gcc/g++`. Dev/diagnostic tools: `vim`, `less`, `nano`, `tmux`, `htop`,
`tree`, `jq`, `diff`, `xxd`, `valgrind`, `strace`, `gdb`, `unzip`/`zip`,
`ping`, `traceroute`, `mtr`, `ip`, `ss`, `dig`, `nslookup`, `nc`, `ssh`.

## Tag scheme

`zephyr_ncs_bundle:<NCS_VER>-<CFG_REV>` — e.g. `zephyr_ncs_bundle:3.3.0-1.0`.

- `NCS_VER` tracks the pinned NCS release. NCS is the anchor: pinning it
  transitively pins sdk-zephyr, MCUboot, TF-M, nrfxlib, etc.
- `CFG_REV` bumps on Dockerfile / entrypoint / Makefile changes against the
  same NCS. Bumping NCS resets `CFG_REV` to `1.0`.

## Build the image

From this directory:

```bash
make image                            # defaults: NCS v3.3.0, ARM-only
make image NCS_VERSION=3.2.0 CFG_REV=1.0   # different NCS release
make image INCLUDE_VPR=1               # add riscv64-zephyr-elf for nRF54H20 VPR cores
make image JFROG_VERSION=2.104.0       # bump JFrog CLI
```

## Corporate TLS inspection

The `certs/` directory is **empty by default and gitignored** — no CAs are
committed. If your network performs TLS inspection (Zscaler, Bluecoat,
enterprise MITM proxies, etc.) and the build fails on `west update` or the
JFrog CLI download with SSL errors, drop the relevant root + intermediate
`*.crt` files into `certs/` before running `make image`. They will be copied
into the image and trusted by the system bundle plus tools that use certifi
(pip, python-requests, west) via `SSL_CERT_FILE` / `REQUESTS_CA_BUNDLE` /
`PIP_CERT` / `GIT_SSL_CAINFO`. With an empty `certs/`, this layer is a
harmless no-op.

## Run modes

The container accepts source two ways. Both write outputs to a bind-mounted
`/artifacts` directory.

**Mount mode** (default; used by `make build`): bind-mount source at `/workdir`.

```bash
docker run --rm \
    -v "$PWD":/workdir \
    -v "$PWD/artifacts":/artifacts \
    -e BOARD=nrf5340dk/nrf5340/cpuapp \
    -e APP=app \
    zephyr_ncs_bundle:3.3.0-1.0
```

**Clone mode**: set `GIT_URL` and the container clones into `/tmp`, builds,
and copies artifacts out. Nothing persists inside the image.

```bash
docker run --rm \
    -e GIT_URL=https://gitlab.example.com/group/firmware.git \
    -e GIT_REF=main \
    -e BOARD=nrf5340dk/nrf5340/cpuapp \
    -e APP=app \
    -v "$PWD/out":/artifacts \
    zephyr_ncs_bundle:3.3.0-1.0
```

## Environment variables

| Var               | Default       | Purpose                                                  |
|-------------------|---------------|----------------------------------------------------------|
| `BOARD`           | (required)    | `west build -b` target, e.g. `nrf5340dk/nrf5340/cpuapp`. |
| `APP`             | `.`           | Path inside `/workdir` (or cloned tree) to the app.      |
| `GIT_URL`         | unset         | If set, enables clone mode.                              |
| `GIT_REF`         | `main`        | Git ref for clone mode.                                  |
| `BUILD_DIR`       | `/tmp/build`  | Override west build directory.                           |
| `WEST_BUILD_ARGS` | empty         | Extra args appended after `--` to `west build`.          |

## Subcommands

```bash
docker run … zephyr_ncs_bundle:3.3.0-1.0                  # default: build
docker run … zephyr_ncs_bundle:3.3.0-1.0 west list        # any west command
docker run -it … zephyr_ncs_bundle:3.3.0-1.0 shell        # interactive bash
docker run --rm zephyr_ncs_bundle:3.3.0-1.0 <any cmd>     # exec arbitrary command
```

The last form makes the image usable as a generic NCS-environment container,
e.g. `docker run --rm zephyr_ncs_bundle:3.3.0-1.0 jf rt ping`.

## Artifact layout (output)

Per build, written to `/artifacts/<board_sanitized>/`:

- `merged.hex` (and `merged_domains.hex` / `tfm_merged.hex` if produced) at
  the top level — sysbuild's final merged image(s).
- One subdirectory per image (typically `app/`) containing that image's own
  `zephyr.hex`, `zephyr.bin`, `zephyr.elf`, `zephyr.dts`.

Non-sysbuild builds (single image, no sub-images) skip the subdirectory and
drop `zephyr.{hex,bin,elf,dts}` directly under `<board_sanitized>/`.

## Paths inside the image

| Path                                  | Contents                                          |
|---------------------------------------|---------------------------------------------------|
| `/opt/ncs`                            | NCS workspace (sdk-nrf + sdk-zephyr + modules).   |
| `/opt/zephyr-sdk`                     | Symlink → `/opt/zephyr-sdk-0.17.4`.               |
| `/opt/venv`                           | Python venv with `west` and NCS Python deps.     |
| `/workdir`                            | Bind-mount target for project source.             |
| `/artifacts`                          | Bind-mount target for build outputs.              |
| `/ccache`                             | Bind-mount target for ccache (5 GB max).          |
| `/etc/ssl/certs/ca-certificates.crt`  | System CA bundle incl. certs from `certs/`.       |
| `/usr/local/bin/zephyr-entrypoint.sh` | Entrypoint script.                                |

Runs as user `zephyr` (UID 1000).

## Verify the image (without any user source)

```bash
docker run --rm zephyr_ncs_bundle:3.3.0-1.0 west list zephyr nrf
docker run --rm zephyr_ncs_bundle:3.3.0-1.0 west build \
    -b nrf5340dk/nrf5340/cpuapp \
    -s /opt/ncs/zephyr/samples/hello_world \
    -d /tmp/b
```

A clean hello_world build inside the image takes ~20 s (everything offline).
