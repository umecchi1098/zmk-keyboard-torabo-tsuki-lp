#!/usr/bin/env bash
set -euo pipefail

# このスクリプトは、ビルド後のKconfigとUF2を確認します。
# Settings RPCが左右へ正しく配置され、省電力の初期値が維持されていることを検査します。
readonly repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly build_dir="${repo_dir}/.build/local/dya"
readonly left_dir="${build_dir}/torabo_tsuki_lp_left_peripheral"
readonly right_dir="${build_dir}/torabo_tsuki_lp_right_central"
readonly develop_dir="${build_dir}/torabo_tsuki_lp_right_central_develop"
readonly double_left_dir="${build_dir}/torabo_tsuki_lp_double_ball_left_peripheral"
readonly double_right_dir="${build_dir}/torabo_tsuki_lp_double_ball_right_central"
readonly reset_dir="${build_dir}/settings_reset-bmp_boost-zmk"

fail() {
    echo "ERROR: $1" >&2
    exit 1
}

require_file() {
    [[ -f "$1" ]] || fail "検査対象ファイルがありません: $1"
}

assert_contains() {
    local file="$1"
    local expected="$2"
    local description="$3"
    rg --quiet --fixed-strings -- "$expected" "$file" || fail "$description"
}

# UF2は512バイトのブロックに分かれています。
# 管理情報を除いたFirmware部分を連結し、RPC識別子が実際に組み込まれたか確認します。
uf2_contains() {
    local file="$1"
    local expected="$2"

    python3 - "$file" "$expected" <<'PY'
import struct
import sys
from pathlib import Path

uf2 = Path(sys.argv[1]).read_bytes()
expected = sys.argv[2].encode("ascii")

# 壊れたUF2を正常と判定しないよう、サイズと各ブロックの識別値も確認します。
if len(uf2) % 512 != 0:
    raise SystemExit(1)

firmware = bytearray()
for offset in range(0, len(uf2), 512):
    block = uf2[offset : offset + 512]
    magic_start, magic_second = struct.unpack_from("<II", block, 0)
    if magic_start != 0x0A324655 or magic_second != 0x9E5D5157:
        raise SystemExit(1)

    payload_size = struct.unpack_from("<I", block, 16)[0]
    if payload_size > 476:
        raise SystemExit(1)
    firmware.extend(block[32 : 32 + payload_size])

raise SystemExit(0 if expected in firmware else 1)
PY
}

check_common() {
    local artifact_dir="$1"
    local kconfig="${artifact_dir}/kconfig"
    local artifact_name="${artifact_dir##*/}"

    require_file "$kconfig"
    assert_contains "$kconfig" 'CONFIG_ZMK_SETTINGS_RPC=y' \
        "${artifact_name}: Settings RPC本体が有効ではありません"
    assert_contains "$kconfig" 'CONFIG_ZMK_SPLIT_RELAY_EVENT=y' \
        "${artifact_name}: 左右同期に必要なSplit Relayが有効ではありません"
    assert_contains "$kconfig" 'CONFIG_ZMK_SETTINGS_SAVE_DEBOUNCE=10000' \
        "${artifact_name}: 設定保存待ち時間が10秒ではありません"
    assert_contains "$kconfig" 'CONFIG_ZMK_IDLE_TIMEOUT=30000' \
        "${artifact_name}: Idleの初期値が30秒ではありません"
    assert_contains "$kconfig" 'CONFIG_ZMK_IDLE_SLEEP_TIMEOUT=9000000' \
        "${artifact_name}: Deep Sleepの初期値が150分ではありません"
}

check_central() {
    local artifact_dir="$1"
    local kconfig="${artifact_dir}/kconfig"
    local artifact_name="${artifact_dir##*/}"
    local uf2="${artifact_dir}/${artifact_name}.uf2"

    check_common "$artifact_dir"
    require_file "$uf2"
    assert_contains "$kconfig" 'CONFIG_ZMK_SETTINGS_RPC_STUDIO=y' \
        "${artifact_name}: DYA Studio用Settings RPCが有効ではありません"
    uf2_contains "$uf2" 'zmk__settings' || \
        fail "${artifact_name}: UF2にSettings RPC識別子がありません"
}

check_peripheral() {
    local artifact_dir="$1"
    local kconfig="${artifact_dir}/kconfig"
    local artifact_name="${artifact_dir##*/}"
    local uf2="${artifact_dir}/${artifact_name}.uf2"

    check_common "$artifact_dir"
    require_file "$uf2"
    assert_contains "$kconfig" '# CONFIG_ZMK_SETTINGS_RPC_STUDIO is not set' \
        "${artifact_name}: PeripheralでDYA Studio用RPCが無効ではありません"
    if uf2_contains "$uf2" 'zmk__settings'; then
        fail "${artifact_name}: PeripheralのUF2にSettings RPC識別子が入っています"
    fi
}

check_central "$right_dir"
check_central "$develop_dir"
check_central "$double_right_dir"
check_peripheral "$left_dir"
check_peripheral "$double_left_dir"

# Settings Resetは保存領域を初期化する専用Firmwareで、通常のSettings RPCは不要です。
readonly reset_kconfig="${reset_dir}/kconfig"
readonly reset_uf2="${reset_dir}/settings_reset-bmp_boost-zmk.uf2"
require_file "$reset_kconfig"
require_file "$reset_uf2"
assert_contains "$reset_kconfig" '# CONFIG_ZMK_SETTINGS_RPC is not set' \
    "Settings ResetへSettings RPCが入っています"
if uf2_contains "$reset_uf2" 'zmk__settings'; then
    fail "Settings ResetのUF2にSettings RPC識別子が入っています"
fi

echo "Settings RPCのKconfig/UF2検査に成功しました。"
