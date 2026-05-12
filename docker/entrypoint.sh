#!/usr/bin/env bash
# zephyr_ncs_bundle entrypoint.
# Dispatches one of: build (default) | test | shell | west.
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

        # Top-level sysbuild outputs: merged image(s) + partition/domain layout.
        for f in merged.hex merged_domains.hex tfm_merged.hex \
                 partitions.yml domains.yaml; do
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
            # Flashable artifacts + memory-analysis inputs:
            #   zephyr.map   linker map (full symbol layout, addresses, sizes)
            #   .config      final Kconfig (which features are compiled in)
            #   zephyr.lst   disassembly listing (only if generated)
            # MCUboot-signed variants (zephyr.signed.*) are copied when MCUboot
            # is enabled in the build — these are the OTA payload format.
            for f in zephyr.hex zephyr.bin zephyr.elf zephyr.dts \
                     zephyr.map zephyr.lst .config \
                     zephyr.signed.hex zephyr.signed.bin \
                     zephyr.signed.encrypted.hex zephyr.signed.encrypted.bin; do
                [[ -f "$zdir/$f" ]] && cp "$zdir/$f" "$dest/"
            done
            # Human-readable ROM/RAM breakdowns from Zephyr's built-in
            # reports. Re-runs cmake/ninja against the build tree, prints
            # hierarchical text. Cheap (seconds) since everything is cached.
            local img_build_dir
            img_build_dir="$(dirname "$zdir")"
            if ninja -C "$img_build_dir" rom_report >"$dest/rom_report.txt" 2>/dev/null; then
                info "  rom_report → ${dest#$board_dir/}/rom_report.txt"
            else
                rm -f "$dest/rom_report.txt"
            fi
            if ninja -C "$img_build_dir" ram_report >"$dest/ram_report.txt" 2>/dev/null; then
                info "  ram_report → ${dest#$board_dir/}/ram_report.txt"
            else
                rm -f "$dest/ram_report.txt"
            fi
            found=1
        done
        shopt -u nullglob

        [[ $found -eq 1 ]] || info "no build outputs found under $build_dir"
    fi
}

cmd_test() {
    local tests_root="/workdir/${TESTS:-tests}"
    [[ -d "$tests_root" ]] || { err "tests dir not found: $tests_root"; exit 2; }

    info "discovering tests under $tests_root"
    cd /opt/ncs

    local pass=0 fail=0 total=0
    [[ -d /artifacts ]] && mkdir -p /artifacts/tests

    while IFS= read -r cmake; do
        local test_src test_name build_dir log_file dest
        test_src="$(dirname "$cmake")"
        test_name="${test_src#$tests_root/}"
        test_name="${test_name//\//_}"
        build_dir="/tmp/test-build/$test_name"
        dest="/artifacts/tests/$test_name"
        log_file="$dest/output.txt"

        total=$((total + 1))
        info "--- test: $test_name ---"
        [[ -d /artifacts ]] && mkdir -p "$dest"

        # Host-compiled unit test via `find_package(Zephyr COMPONENTS unittest)`.
        # Pure CMake — no west, no sysbuild, no board. Output: ./testbinary.
        # Bypass west entirely so the unit-test path stays simple and the test
        # binary is a plain x86 Linux executable (gdb / valgrind / asan friendly).
        if mkdir -p "$build_dir" && \
           cmake -GNinja -B "$build_dir" -S "$test_src" \
               -DBOARD=unit_testing \
               -DZEPHYR_BASE=/opt/ncs/zephyr 2>&1 | { [[ -d /artifacts ]] && tee "$log_file" || cat; } && \
           cmake --build "$build_dir" 2>&1 | { [[ -d /artifacts ]] && tee -a "$log_file" || cat; } && \
           "$build_dir/testbinary" 2>&1 | { [[ -d /artifacts ]] && tee -a "$log_file" || cat; }; then
            [[ -d /artifacts && -f "$build_dir/testbinary" ]] && cp "$build_dir/testbinary" "$dest/"
            pass=$((pass + 1))
            info "  PASS: $test_name"
        else
            fail=$((fail + 1))
            info "  FAIL: $test_name"
        fi
    done < <(find "$tests_root" -name CMakeLists.txt | sort)

    info "============================================"
    info "tests: $total total, $pass passed, $fail failed"
    [[ $fail -eq 0 ]]
}

case "$SUBCOMMAND" in
    build) cmd_build "$@" ;;
    test)  cmd_test ;;
    shell) cmd_shell ;;
    west)  cmd_west "$@" ;;
    *)     # Anything else: exec verbatim so the image is also usable as a
           # generic "do stuff in this environment" container, e.g.
           # `docker run image bash -c '...'`, `docker run image ls /opt`.
           exec "$SUBCOMMAND" "$@"
           ;;
esac
