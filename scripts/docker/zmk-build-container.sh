#!/usr/bin/env bash
set -euo pipefail

readonly repo_dir=/repo
readonly workspace_dir=/workspaces/west
readonly config_dir="${workspace_dir}/config"
readonly build_env="${ZMK_BUILD_ENV:?ZMK_BUILD_ENV is required}"
readonly output_root="/output/local/${build_env}"
readonly artifact_filter="${ARTIFACT_FILTER:-}"

is_selected() {
    local artifact_name="$1"
    [[ -z "$artifact_filter" ]] && return 0
    [[ ",${artifact_filter}," == *",${artifact_name},"* ]]
}

fix_output_owner() {
    if [[ -n "${HOST_UID:-}" && -n "${HOST_GID:-}" ]]; then
        chown -R "${HOST_UID}:${HOST_GID}" "$output_root" 2>/dev/null || true
    fi
}

trap fix_output_owner EXIT

mkdir -p "$workspace_dir" "$output_root"
rm -rf -- "$config_dir"
cp -a "${repo_dir}/config" "$config_dir"

cd "$workspace_dir"

if [[ ! -d .west ]]; then
    west init -l config
fi

west update --fetch-opt=--filter=tree:0
west zephyr-export

python3 - "${repo_dir}/build.yaml" <<'PY' > /tmp/zmk-build-matrix.txt
import sys
from pathlib import Path

import yaml

matrix = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8")) or {}
for item in matrix.get("include", []):
    board = str(item["board"])
    shield = str(item.get("shield", ""))
    snippet = str(item.get("snippet", ""))
    artifact = str(item.get("artifact-name") or f"{shield + '-' if shield else ''}{board.replace('/', '_')}-zmk")
    cmake_args = str(item.get("cmake-args", ""))
    fields = (board, shield, snippet, artifact, cmake_args)
    if any("\x1f" in field or "\n" in field for field in fields):
        raise SystemExit(f"build.yaml contains an unsupported separator or newline: {artifact}")
    print("\x1f".join(fields))
PY

selected_count=0
while IFS=$'\x1f' read -r board shield snippet artifact_name cmake_args; do
    if ! is_selected "$artifact_name"; then
        continue
    fi

    selected_count=$((selected_count + 1))
    build_dir="${workspace_dir}/build/${artifact_name}"
    artifact_dir="${output_root}/${artifact_name}"
    log_file="${artifact_dir}/build.log"

    rm -rf -- "$artifact_dir"
    mkdir -p "$artifact_dir"

    west_args=(build -s zmk/app -d "$build_dir" -b "$board" --pristine)
    if [[ -n "$snippet" ]]; then
        west_args+=(-S "$snippet")
    fi

    cmake_options=("-DZMK_CONFIG=${config_dir}" "-DZMK_EXTRA_MODULES=${repo_dir}")
    if [[ -n "$shield" ]]; then
        cmake_options+=("-DSHIELD=${shield}")
    fi
    if [[ -n "$cmake_args" ]]; then
        read -r -a extra_cmake_options <<< "$cmake_args"
        cmake_options+=("${extra_cmake_options[@]}")
    fi

    echo "==> Building ${artifact_name} (${board}${shield:+ / ${shield}})"
    west "${west_args[@]}" -- "${cmake_options[@]}" 2>&1 | tee "$log_file"

    if [[ -f "${build_dir}/zephyr/zmk.uf2" ]]; then
        cp "${build_dir}/zephyr/zmk.uf2" "${artifact_dir}/${artifact_name}.uf2"
    elif [[ -f "${build_dir}/zephyr/zmk.bin" ]]; then
        cp "${build_dir}/zephyr/zmk.bin" "${artifact_dir}/${artifact_name}.bin"
    else
        echo "ERROR: ${artifact_name} のファームウェア成果物が見つかりません。" >&2
        exit 1
    fi

    [[ -f "${build_dir}/zephyr/.config" ]] && cp "${build_dir}/zephyr/.config" "${artifact_dir}/kconfig"
    [[ -f "${build_dir}/zephyr/zephyr.dts" ]] && cp "${build_dir}/zephyr/zephyr.dts" "${artifact_dir}/zephyr.dts"
    elf_file=""
    for candidate in "${build_dir}/zephyr/zmk.elf" "${build_dir}/zephyr/zephyr.elf"; do
        if [[ -f "$candidate" ]]; then
            elf_file="$candidate"
            break
        fi
    done
    if [[ -n "$elf_file" ]]; then
        size_tool="$(command -v arm-zephyr-eabi-size || true)"
        if [[ -z "$size_tool" ]]; then
            size_tool="$(find /opt -path '*/arm-zephyr-eabi/bin/arm-zephyr-eabi-size' -print -quit 2>/dev/null || true)"
        fi
        if [[ -n "$size_tool" ]]; then
            "$size_tool" "$elf_file" | tee "${artifact_dir}/firmware-size.txt"
        else
            echo "WARNING: size toolが見つからないため、firmware-size.txtを生成できません。" >&2
        fi
    fi
done < /tmp/zmk-build-matrix.txt

if (( selected_count == 0 )); then
    echo "ERROR: 指定された成果物がbuild.yamlにありません: ${artifact_filter}" >&2
    exit 1
fi

echo "Build completed: ${output_root}"
