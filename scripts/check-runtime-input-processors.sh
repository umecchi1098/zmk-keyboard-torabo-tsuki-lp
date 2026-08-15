#!/usr/bin/env bash
set -euo pipefail

# このスクリプトは、ビルド後のDevicetreeとKconfigがフェーズ6の設計値どおりか確認します。
# 実機を接続しなくても、左右の処理順や既定値が意図せず変わったことを検出できます。
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

# 指定したDevicetree nodeの開始行から、最初の閉じ括弧までを取り出します。
node_block() {
    local file="$1"
    local node_label="$2"
    awk -v label="$node_label" '
        index($0, label) { found = 1 }
        found { print }
        found && /^[[:space:]]*};/ { exit }
    ' "$file"
}

assert_node_contains() {
    local file="$1"
    local node_label="$2"
    local expected="$3"
    local description="$4"
    local block
    block="$(node_block "$file" "$node_label")"
    [[ -n "$block" ]] || fail "Devicetree nodeがありません: $node_label"
    rg --quiet --fixed-strings -- "$expected" <<<"$block" || fail "$description"
}

assert_node_not_contains() {
    local file="$1"
    local node_label="$2"
    local unexpected="$3"
    local description="$4"
    local block
    block="$(node_block "$file" "$node_label")"
    [[ -n "$block" ]] || fail "Devicetree nodeがありません: $node_label"
    if rg --quiet --fixed-strings -- "$unexpected" <<<"$block"; then
        fail "$description"
    fi
}

readonly left_dts="${left_dir}/zephyr.dts"
readonly right_dts="${right_dir}/zephyr.dts"
readonly double_left_dts="${double_left_dir}/zephyr.dts"
readonly double_right_dts="${double_right_dir}/zephyr.dts"
readonly left_kconfig="${left_dir}/kconfig"
readonly right_kconfig="${right_dir}/kconfig"
readonly develop_kconfig="${develop_dir}/kconfig"
readonly double_right_kconfig="${double_right_dir}/kconfig"

for file in "$left_dts" "$right_dts" "$double_left_dts" "$double_right_dts" \
    "$left_kconfig" "$right_kconfig" "$develop_kconfig" "$double_right_kconfig"; do
    require_file "$file"
done

# 標準版は従来どおり右側1台だけを使い、左側へポインタードライバーを追加しません。
assert_not_contains "$left_dts" 'compatible = "zmk,input-split";' \
    "標準の左PeripheralへSplit Input送信nodeが組み込まれています"
assert_not_contains "$left_dts" 'compatible = "zmk,input-processor-runtime";' \
    "左PeripheralへRuntime Processorが組み込まれています"
assert_contains "$left_kconfig" '# CONFIG_ZMK_RUNTIME_INPUT_PROCESSOR is not set' \
    "左PeripheralでRuntime Input Processorが無効になっていません"

# double-ballの左Peripheralは入力を加工せず右Centralへ送ります。
assert_contains "$double_left_dts" 'compatible = "zmk,input-split";' \
    "double-ball左PeripheralにSplit Input送信nodeがありません"
assert_not_contains "$double_left_dts" 'compatible = "zmk,input-processor-runtime";' \
    "double-ball左PeripheralへRuntime Processorが組み込まれています"

# 標準の右CentralはLocal用2つ、double-ball版はSplit用を加えた4つが必要です。
readonly processor_count="$(rg --count 'compatible = "zmk,input-processor-runtime";' "$right_dts")"
[[ "$processor_count" == "2" ]] || fail "標準の右CentralのRuntime Processor数が2ではありません: ${processor_count}"
readonly double_processor_count="$(rg --count 'compatible = "zmk,input-processor-runtime";' "$double_right_dts")"
[[ "$double_processor_count" == "4" ]] || fail "double-ball右CentralのRuntime Processor数が4ではありません: ${double_processor_count}"

assert_node_contains "$right_dts" 'mouse_runtime_input_processor:' 'processor-label = "mouse";' \
    "右Mouseの識別子が一致しません"
assert_node_contains "$right_dts" 'mouse_runtime_input_processor:' 'temp-layer = < 0x2 >;' \
    "右Mouseの対象がLayer 2ではありません"
assert_node_contains "$right_dts" 'mouse_runtime_input_processor:' 'temp-layer-activation-delay-ms = < 0x96 >;' \
    "右Mouseの有効化待ち時間が150msではありません"
assert_node_contains "$right_dts" 'mouse_runtime_input_processor:' 'temp-layer-deactivation-delay-ms = < 0x1f4 >;' \
    "右Mouseの解除時間が500msではありません"
assert_node_contains "$right_dts" 'mouse_runtime_input_processor:' 'x-invert;' \
    "右MouseのX反転がありません"
assert_node_contains "$right_dts" 'mouse_runtime_input_processor:' 'y-invert;' \
    "右MouseのY反転がありません"

assert_node_contains "$right_dts" 'scroll_runtime_input_processor:' 'processor-label = "scroll";' \
    "右Scrollの識別子が一致しません"
assert_node_contains "$right_dts" 'scroll_runtime_input_processor:' 'scale-divisor = < 0x40 >;' \
    "右Scrollの倍率が1/64ではありません"
assert_node_contains "$right_dts" 'scroll_runtime_input_processor:' 'active-layers = < 0x40 >;' \
    "右Scrollの対象がLayer 6ではありません"
assert_node_contains "$right_dts" 'scroll_runtime_input_processor:' 'xy-to-scroll-enabled;' \
    "右ScrollのXY変換がありません"
assert_node_contains "$right_dts" 'scroll_runtime_input_processor:' 'x-invert;' \
    "右ScrollのX反転がありません"
assert_node_not_contains "$right_dts" 'scroll_runtime_input_processor:' 'y-invert;' \
    "右ScrollでYまで反転されています"

assert_node_contains "$double_right_dts" 'split_mouse_runtime_input_processor:' 'processor-label = "lmouse";' \
    "左Mouseの識別子が一致しません"
assert_node_contains "$double_right_dts" 'split_mouse_runtime_input_processor:' 'temp-layer = < 0x2 >;' \
    "左Mouseの対象がLayer 2ではありません"
assert_node_contains "$double_right_dts" 'split_mouse_runtime_input_processor:' 'temp-layer-deactivation-delay-ms = < 0x320 >;' \
    "左Mouseの解除時間が800msではありません"
assert_node_contains "$double_right_dts" 'split_mouse_runtime_input_processor:' 'x-invert;' \
    "左MouseのX反転がありません"
assert_node_contains "$double_right_dts" 'split_mouse_runtime_input_processor:' 'y-invert;' \
    "左MouseのY反転がありません"

assert_node_contains "$double_right_dts" 'split_scroll_runtime_input_processor:' 'processor-label = "lscroll";' \
    "左Scrollの識別子が一致しません"
assert_node_contains "$double_right_dts" 'split_scroll_runtime_input_processor:' 'scale-divisor = < 0x40 >;' \
    "左Scrollの倍率が1/64ではありません"
assert_node_contains "$double_right_dts" 'split_scroll_runtime_input_processor:' 'active-layers = < 0x40 >;' \
    "左Scrollの対象がLayer 6ではありません"
assert_node_contains "$double_right_dts" 'split_scroll_runtime_input_processor:' 'xy-to-scroll-enabled;' \
    "左ScrollのXY変換がありません"
assert_node_contains "$double_right_dts" 'split_scroll_runtime_input_processor:' 'x-invert;' \
    "左ScrollのX反転がありません"
assert_node_not_contains "$double_right_dts" 'split_scroll_runtime_input_processor:' 'y-invert;' \
    "左ScrollでYまで反転されています"

# Scrollを先、Mouseを後にすることで、旧process-nextと同じ流れを維持します。
assert_contains "$right_dts" \
    'input-processors = < &scroll_runtime_input_processor &mouse_runtime_input_processor >;' \
    "Local Input Listenerの処理順がScroll→Mouseではありません"
assert_contains "$double_right_dts" \
    'input-processors = < &split_scroll_runtime_input_processor &split_mouse_runtime_input_processor >;' \
    "Split Input Listenerの処理順がScroll→Mouseではありません"

assert_not_contains "$right_dts" 'auto_mouse_layer' \
    "旧auto_mouse_layerが右Centralに残っています"
assert_not_contains "$right_dts" 'zmk,input-processor-temp-layer' \
    "旧Temp Layer Processorが右Centralに残っています"
assert_not_contains "$double_right_dts" 'auto_mouse_layer' \
    "旧auto_mouse_layerがdouble-ball右Centralに残っています"

# 本番版はLock保護を有効にし、開発版だけLockを無効にします。
assert_contains "$right_kconfig" 'CONFIG_ZMK_RUNTIME_INPUT_PROCESSOR=y' \
    "右CentralでRuntime Input Processorが有効ではありません"
assert_contains "$right_kconfig" 'CONFIG_ZMK_RUNTIME_INPUT_PROCESSOR_STUDIO_RPC=y' \
    "右CentralでRuntime Input Processor RPCが有効ではありません"
assert_contains "$right_kconfig" 'CONFIG_TORABO_TSUKI_LP_SECURE_RUNTIME_INPUT_PROCESSOR_RPC=y' \
    "右Centralで追加のStudio Lock保護が有効ではありません"
assert_contains "$right_kconfig" 'CONFIG_ZMK_STUDIO_LOCKING=y' \
    "本番版でStudio Lockが有効ではありません"
assert_contains "$double_right_kconfig" 'CONFIG_TORABO_TSUKI_LP_SECURE_RUNTIME_INPUT_PROCESSOR_RPC=y' \
    "double-ball右Centralで追加のStudio Lock保護が有効ではありません"
assert_contains "$double_right_kconfig" 'CONFIG_ZMK_STUDIO_LOCKING=y' \
    "double-ball右CentralでStudio Lockが有効ではありません"
assert_contains "$develop_kconfig" '# CONFIG_ZMK_STUDIO_LOCKING is not set' \
    "開発版でStudio Lockが無効ではありません"

echo "Runtime Input ProcessorのDevicetree/Kconfig検査に成功しました。"
