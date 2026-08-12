#!/usr/bin/env bash
set -euo pipefail

readonly repo_dir=/repo
readonly workspace_dir=/workspaces/west
readonly config_dir="${workspace_dir}/config"
readonly build_root="${workspace_dir}/build"
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

mkdir -p "$workspace_dir" "$build_root" "$output_root"
rm -rf -- "$config_dir"
cp -a "${repo_dir}/config" "$config_dir"

cd "$workspace_dir"

if [[ ! -d .west ]]; then
    west init -l config --mf west-standalone.yml
else
    # 既存Volumeを使う場合も、新しいstandalone Manifestを明示します。
    west config manifest.path config
    west config manifest.file west-standalone.yml
fi

west update --narrow
west zephyr-export

python3 - "${repo_dir}/build.yaml" <<'PY' > /tmp/zmk-build-artifacts.txt
import sys
from pathlib import Path

import yaml

matrix = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8")) or {}
for item in matrix.get("include", []):
    artifact = str(item.get("artifact", ""))
    if not artifact:
        raise SystemExit("build.yamlの各項目にはartifactが必要です。")
    if not artifact.replace("-", "").replace("_", "").isalnum():
        raise SystemExit(f"artifactに使用できない文字が含まれています: {artifact}")
    print(artifact)
PY

selected_artifacts=()
while IFS= read -r artifact_name; do
    if ! is_selected "$artifact_name"; then
        continue
    fi
    selected_artifacts+=("$artifact_name")
done < /tmp/zmk-build-artifacts.txt

if (( ${#selected_artifacts[@]} == 0 )); then
    echo "ERROR: 指定された成果物がbuild.yamlにありません: ${artifact_filter}" >&2
    exit 1
fi

# DYA2公式と同じwest拡張コマンドで、build.yamlの有効項目をビルドします。
west_command=(west zmk-build "$repo_dir" -d "$build_root" -P 1)
if [[ -n "$artifact_filter" ]]; then
    selected_regex="$(IFS='|'; printf '%s' "${selected_artifacts[*]}")"
    west_command+=(-af "^(${selected_regex})$")
fi
"${west_command[@]}"

for artifact_name in "${selected_artifacts[@]}"; do
    build_dir="${build_root}/${artifact_name}"
    artifact_dir="${output_root}/${artifact_name}"

    rm -rf -- "$artifact_dir"
    mkdir -p "$artifact_dir"

    if [[ -f "${build_dir}/zephyr/zmk.uf2" ]]; then
        cp "${build_dir}/zephyr/zmk.uf2" "${artifact_dir}/${artifact_name}.uf2"
    elif [[ -f "${build_dir}/zephyr/zmk.bin" ]]; then
        cp "${build_dir}/zephyr/zmk.bin" "${artifact_dir}/${artifact_name}.bin"
    else
        echo "ERROR: ${artifact_name} のファームウェア成果物が見つかりません。" >&2
        exit 1
    fi

    [[ -f "${build_dir}/stdout_and_stderr.log" ]] && cp "${build_dir}/stdout_and_stderr.log" "${artifact_dir}/build.log"
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
done

echo "Build completed: ${output_root}"
