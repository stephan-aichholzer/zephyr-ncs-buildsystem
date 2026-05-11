#!/usr/bin/env bash
# zephyr_ncs_bundle entrypoint.
# Dispatches one of: build (default) | shell | west.
# Build mode is one of:
#   - mount mode (default): source is bind-mounted at /workdir
#   - clone mode:           triggered by env GIT_URL; clones into /tmp/src
set -euo pipefail

SUBCOMMAND="${1:-build}"
[[ $# -gt 0 ]] && shift || true

err()  { echo "zephyr-entrypoint: ERROR: $*" >&2; }
info() { echo "zephyr-entrypoint: $*" >&2; }

cmd_shell() {
    exec bash -l
}

cmd_west() {
    cd /opt/ncs
    exec west "$@"
}

cmd_build() {
    [[ -n "${BOARD:-}" ]] || {
        err "BOARD env var is required (e.g. BOARD=nrf5340dk/nrf5340/cpuapp)"
        exit 2
    }

    local src_root
    if [[ -n "${GIT_URL:-}" ]]; then
        src_root=/tmp/src
        rm -rf "$src_root"
        info "clone mode: $GIT_URL @ ${GIT_REF:-main}"
        git clone --depth 1 --branch "${GIT_REF:-main}" "$GIT_URL" "$src_root"
    else
        src_root=/workdir
        if [[ ! -d "$src_root" ]] || [[ -z "$(ls -A "$src_root" 2>/dev/null || true)" ]]; then
            err "/workdir is empty. Bind-mount your source or set GIT_URL."
            exit 2
        fi
    fi

    local app_path="${APP:-.}"
    local src_dir="$src_root/$app_path"
    [[ -d "$src_dir" ]] || { err "app dir not found: $src_dir"; exit 2; }

    local build_dir="${BUILD_DIR:-/tmp/build}"

    info "building BOARD=$BOARD APP=$src_dir BUILD_DIR=$build_dir"
    cd /opt/ncs
    # shellcheck disable=SC2086
    west build -b "$BOARD" -s "$src_dir" -d "$build_dir" -- ${WEST_BUILD_ARGS:-} "$@"

    if [[ -d /artifacts ]]; then
        local board_dir="/artifacts/${BOARD//\//_}"
        mkdir -p "$board_dir"
        info "copying artifacts to $board_dir"

        # Top-level sysbuild outputs (merged image[s]).
        for f in merged.hex merged_domains.hex tfm_merged.hex; do
            [[ -f "$build_dir/$f" ]] && cp "$build_dir/$f" "$board_dir/"
        done

        # Per-image artifacts. Sysbuild layout: $BUILD_DIR/<image>/zephyr/*
        # Non-sysbuild legacy: $BUILD_DIR/zephyr/* (no <image> subdir).
        shopt -s nullglob
        local found=0
        for zdir in "$build_dir"/*/zephyr "$build_dir"/zephyr; do
            [[ -d "$zdir" ]] || continue
            local image
            image="$(basename "$(dirname "$zdir")")"
            [[ "$image" == "_sysbuild" ]] && continue
            # When the only zdir is $BUILD_DIR/zephyr, drop the image subdir.
            local dest="$board_dir"
            [[ "$image" != "$(basename "$build_dir")" ]] && dest="$board_dir/$image"
            mkdir -p "$dest"
            for f in zephyr.hex zephyr.bin zephyr.elf zephyr.dts; do
                [[ -f "$zdir/$f" ]] && cp "$zdir/$f" "$dest/"
            done
            found=1
        done
        shopt -u nullglob

        [[ $found -eq 1 ]] || info "no build outputs found under $build_dir"
    fi
}

case "$SUBCOMMAND" in
    build) cmd_build "$@" ;;
    shell) cmd_shell ;;
    west)  cmd_west "$@" ;;
    *)     # Anything else: exec verbatim so the image is also usable as a
           # generic "do stuff in this environment" container, e.g.
           # `docker run image bash -c '...'`, `docker run image ls /opt`.
           exec "$SUBCOMMAND" "$@"
           ;;
esac
