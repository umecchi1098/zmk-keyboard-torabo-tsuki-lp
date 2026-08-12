#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="${repo_dir}/compose.yaml"
environment="auto"
artifact_filter=""

usage() {
    cat <<'EOF'
Usage: ./scripts/zmk-build.sh [auto|baseline|dya] [artifact-name ...]

  auto      config/west-dependency.yml から使用環境を判定（既定）
  baseline  ZMK v0.3 / Zephyr 3.5 用コンテナ
  dya       DYA / Zephyr 4.1 用コンテナ

成果物名を指定すると、その成果物だけをビルドします。
例:
  ./scripts/zmk-build.sh
  ./scripts/zmk-build.sh dya torabo_tsuki_lp_right_central
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ "${1:-}" =~ ^(auto|baseline|dya)$ ]]; then
    environment="$1"
    shift
fi

if (( $# > 0 )); then
    artifact_filter="$(IFS=,; printf '%s' "$*")"
fi

if [[ "$environment" == "auto" ]]; then
    if grep -Eq 'cormoran|main\+dya|v4\.1\.0\+zmk-fixes' "${repo_dir}/config/west-dependency.yml"; then
        environment="dya"
    else
        environment="baseline"
    fi
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker が見つかりません。WSLからDockerを利用できる状態にしてください。" >&2
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: docker compose が利用できません。Docker Compose v2を有効にしてください。" >&2
    exit 1
fi

if [[ -z "${WSL_DISTRO_NAME:-}" ]] || ! grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
    echo "WARNING: 推奨環境はWSL2です。ビルドはDocker内で行うため続行します。" >&2
fi

mkdir -p "${repo_dir}/.build"

export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"

echo "ZMK local build environment: ${environment}"
if [[ -n "$artifact_filter" ]]; then
    echo "Artifacts: ${artifact_filter}"
fi

docker compose -f "$compose_file" run --rm \
    -e "ARTIFACT_FILTER=${artifact_filter}" \
    "$environment"
