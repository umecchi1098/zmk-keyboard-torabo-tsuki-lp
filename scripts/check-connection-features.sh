#!/usr/bin/env bash
set -euo pipefail

# このスクリプトは、ビルド後のKconfigとUF2を確認します。
# 接続管理機能が右Centralだけに入り、既存の左右間通信へ混入しないことを検査します。
readonly repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly build_dir="${repo_dir}/.build/local/dya"
readonly left_dir="${build_dir}/torabo_tsuki_lp_left_peripheral"
readonly right_dir="${build_dir}/torabo_tsuki_lp_right_central"
readonly develop_dir="${build_dir}/torabo_tsuki_lp_right_central_develop"
readonly double_left_dir="${build_dir}/torabo_tsuki_lp_double_ball_left_peripheral"
readonly double_right_dir="${build_dir}/torabo_tsuki_lp_double_ball_right_central"

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

assert_not_contains() {
    local file="$1"
    local unexpected="$2"
    local description="$3"
    if rg --quiet --fixed-strings -- "$unexpected" "$file"; then
        fail "$description"
    fi
}

# UF2は256バイトごとに管理情報が入るため、stringsでは境界上の文字列が分断されます。
# 各ブロックのFirmware部分だけをつなぎ直してから、RPC識別子を確認します。
uf2_contains() {
    local file="$1"
    local expected="$2"

    python3 - "$file" "$expected" <<'PY'
import struct
import sys
from pathlib import Path

uf2 = Path(sys.argv[1]).read_bytes()
expected = sys.argv[2].encode("ascii")

# UF2は512バイト単位です。形式が壊れている場合も検査失敗として扱います。
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

assert_uf2_contains() {
    local file="$1"
    local expected="$2"
    local description="$3"
    uf2_contains "$file" "$expected" || fail "$description"
}

check_central() {
    local artifact_dir="$1"
    local kconfig="${artifact_dir}/kconfig"
    local artifact_name="${artifact_dir##*/}"
    local uf2="${artifact_dir}/${artifact_name}.uf2"

    require_file "$kconfig"
    require_file "$uf2"

    # DYA Studio内蔵の「接続」画面が利用する3つのupstream RPCを確認します。
    assert_contains "$kconfig" 'CONFIG_ZMK_BLE_MANAGEMENT_STUDIO_RPC=y' \
        "${artifact_name}: BLE Management RPCが有効ではありません"
    assert_contains "$kconfig" 'CONFIG_ZMK_OS_DETECTION_STUDIO_RPC=y' \
        "${artifact_name}: OS Detection RPCが有効ではありません"
    assert_contains "$kconfig" 'CONFIG_ZMK_DEFAULT_LAYER_STUDIO_RPC=y' \
        "${artifact_name}: Default Layer RPCが有効ではありません"

    # 接続先の既定値には、BaseとmacOSの2層だけを選べるようにします。
    # Mouseなどの機能レイヤーは一時的に重ねて使うため、選択対象へ含めません。
    assert_contains "$kconfig" 'CONFIG_ZMK_DEFAULT_LAYER_MIN_INDEX=0' \
        "${artifact_name}: Default Layerの最小値が0ではありません"
    assert_contains "$kconfig" 'CONFIG_ZMK_DEFAULT_LAYER_MAX_INDEX=1' \
        "${artifact_name}: Default Layerの最大値が1ではありません"

    # 二重の自動切替を避け、Default Layer側だけがレイヤーを適用します。
    assert_contains "$kconfig" '# CONFIG_ZMK_OS_DETECTION_LAYER_AUTO_SWITCH is not set' \
        "${artifact_name}: 競合するOS Detection側の自動切替が有効です"

    # CentralはSplit用bond 1件と、従来どおりBLEプロファイル5件を持ちます。
    assert_contains "$kconfig" 'CONFIG_BT_MAX_PAIRED=6' \
        "${artifact_name}: BLEプロファイル数に関わる設定が変わっています"

    # UF2内に実際のRPC識別子がリンクされていることも確認します。
    for subsystem in cormoran_ble cormoran__os_detection cormoran__default_layer; do
        assert_uf2_contains "$uf2" "$subsystem" \
            "${artifact_name}: RPC識別子 ${subsystem} がUF2にありません"
    done
}

check_peripheral() {
    local artifact_dir="$1"
    local kconfig="${artifact_dir}/kconfig"
    local artifact_name="${artifact_dir##*/}"
    local uf2="${artifact_dir}/${artifact_name}.uf2"

    require_file "$kconfig"
    require_file "$uf2"

    # 接続先の判定とStudio通信は右Centralの責務です。
    assert_contains "$kconfig" '# CONFIG_ZMK_BLE_MANAGEMENT is not set' \
        "${artifact_name}: PeripheralへBLE Managementが入っています"
    assert_contains "$kconfig" '# CONFIG_ZMK_OS_DETECTION is not set' \
        "${artifact_name}: PeripheralへOS Detectionが入っています"
    assert_contains "$kconfig" '# CONFIG_ZMK_DEFAULT_LAYER is not set' \
        "${artifact_name}: PeripheralへDefault Layerが入っています"

    for subsystem in cormoran_ble cormoran__os_detection cormoran__default_layer; do
        if uf2_contains "$uf2" "$subsystem"; then
            fail "${artifact_name}: PeripheralのUF2にRPC識別子 ${subsystem} が入っています"
        fi
    done
}

check_central "$right_dir"
check_central "$develop_dir"
check_central "$double_right_dir"
check_peripheral "$left_dir"
check_peripheral "$double_left_dir"

# フェーズ1で安定化した省電力時間は変更しません。
for kconfig in "${left_dir}/kconfig" "${right_dir}/kconfig" \
    "${double_left_dir}/kconfig" "${double_right_dir}/kconfig"; do
    assert_contains "$kconfig" 'CONFIG_ZMK_IDLE_TIMEOUT=30000' \
        "Idle移行時間が30秒から変わっています: ${kconfig}"
    assert_contains "$kconfig" 'CONFIG_ZMK_IDLE_SLEEP_TIMEOUT=9000000' \
        "Deep Sleep移行時間が150分から変わっています: ${kconfig}"
done

echo "Connection・Default Layer・OS DetectionのKconfig/UF2検査に成功しました。"
