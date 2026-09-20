#!/usr/bin/env bash
set -euo pipefail

# ビルドが成功しても、左右の入力経路やStudio設定が間違っていないか別途確認します。
# 元のoverlayではなく、実際にファームウェアへ取り込まれた生成物を検査します。
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "${repo_dir}/.build/local/dya" <<'PY'
import re
import sys
from pathlib import Path


def require(condition, message):
    # assert文と異なり、Pythonの最適化設定に関係なく検査を実行します。
    if not condition:
        raise SystemExit(f"検査失敗: {message}")


def node(dts, label):
    # この検査で使う、子ノードを持たないデバイス定義だけを取り出します。
    match = re.search(rf"\b{re.escape(label)}:\s*[^{{]+\{{([^{{}}]*)\}};", dts)
    require(match is not None, f"デバイス定義がありません: {label}")
    return match.group(1)


def contains(text, expected, message):
    require(expected in text, message)


root = Path(sys.argv[1])
builds = {}
for side in ("left_peripheral", "right_central"):
    directory = root / f"torabo_tsuki_lp_mini_trackpad_{side}"
    for filename in ("zephyr.dts", "kconfig", f"{directory.name}.uf2"):
        require((directory / filename).is_file(), f"先に左右をビルドしてください: {filename}")
    builds[side] = (
        (directory / "zephyr.dts").read_text(),
        (directory / "kconfig").read_text(),
    )

left, left_config = builds["left_peripheral"]
right, right_config = builds["right_central"]

# 左でセンサーを読み、右で加工する構成を確認します。両側の番号は0で一致させます。
sensor = node(left, "pointing_device")
for expected in ('compatible = "azoteq,iqs7211e";', "scroller-mode;",
                 'init-symbol = "mini_trackpad_iqs7211e_init";', "init-length = < 0xd9 >;"):
    contains(sensor, expected, f"左センサーの設定が一致しません: {expected}")
for dts in (left, right):
    contains(node(dts, "pointing_device_split"), "reg = < 0x0 >;", "左右のSplit番号が違います")
contains(node(left, "pointing_device_split"), "device = < &pointing_device >;", "左の送信元が違います")
require("device =" not in node(right, "pointing_device_split"), "右の受信側にセンサー指定があります")
contains(left_config, "CONFIG_IQS7211E=y", "左のIQS7211Eドライバーが無効です")
contains(left_config, "CONFIG_IQS7211E_SCROLLER_INERTIA=y", "左の慣性スクロールが無効です")
for config in (left_config, right_config):
    contains(config, "CONFIG_ZMK_INPUT_SPLIT=y", "左右間の入力転送が無効です")
require('compatible = "zmk,input-processor-runtime";' not in left, "左に入力加工が残っています")
contains(right_config, "# CONFIG_IQS7211E is not set", "右に左用センサードライバーが入っています")

# 左のWheel入力をlpadだけに渡します。右のXY入力の経路とは分けて確認します。
listener = node(right, "pointing_device_split_listener")
contains(listener, "device = < &pointing_device_split >;", "左の入力を受信していません")
contains(listener, "input-processors = < &mini_trackpad_runtime_input_processor >;", "左の処理先が違います")
contains(node(right, "pointing_listener"),
         "input-processors = < &scroll_runtime_input_processor &mouse_runtime_input_processor >;",
         "右トラックボールの処理順が変わっています")
labels = re.findall(r'processor-label = "([^"]+)";', right)
require(sorted(labels) == ["lpad", "mouse", "scroll"], f"Studioの設定一覧が違います: {labels}")
processor = node(right, "mini_trackpad_runtime_input_processor")
for expected in ("type = < 0x2 >;", "x-codes = < 0x6 >;", "y-codes = < 0x8 >;",
                 "scale-multiplier = < 0x1 >;", "scale-divisor = < 0x3c >;",
                 "rotation-degrees = < 0x0 >;", "active-layers = < 0x0 >;", "track-remainders;"):
    contains(processor, expected, f"左スクロールの設定が違います: {expected}")
for unwanted in ("xy-to-scroll-enabled;", "xy-swap-enabled;", "temp-layer-enabled;", "x-invert;", "y-invert;"):
    require(unwanted not in processor, f"左の初期状態で不要な変換が有効です: {unwanted}")

# Studioは右側の表示情報を読むため、左装置の位置とリンクも右で確認します。
layout = node(right, "trackpad_physical_layout")
for expected in ('status = "okay";', 'display-name = "Left Mini Trackpad";',
                 "x = < 0xaf >;", 'linked-device-identifiers = "lpad";',
                 'linked-subsystems = "cormoran_rip";'):
    contains(layout, expected, f"Studioの左表示が違います: {expected}")
contains(node(right, "trackball_physical_layout"), 'status = "okay";', "右トラックボールが表示されません")
for expected in ("CONFIG_ZMK_STUDIO_LOCKING=y",
                 "CONFIG_ZMK_RUNTIME_INPUT_PROCESSOR_STUDIO_RPC=y",
                 "CONFIG_ZMK_CUSTOM_SETTINGS=y",
                 "CONFIG_ZMK_PHYSICAL_LAYOUTS_FEATURE_STUDIO_RPC=y",
                 "CONFIG_TORABO_TSUKI_LP_SECURE_RUNTIME_INPUT_PROCESSOR_RPC=y",
                 "# CONFIG_ZMK_POINTING_SMOOTH_SCROLLING is not set"):
    contains(right_config, expected, f"右の設定が違います: {expected}")

print("ミニトラックパッドの左右入力経路・Studio設定・Lock保護の検査に成功しました。")
PY
