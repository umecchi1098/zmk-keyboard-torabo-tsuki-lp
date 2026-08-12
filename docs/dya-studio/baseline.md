# DYA Studio対応前 ベースライン

記録日: 2026-08-12
起点コミット: `0b44ea65ea30b7fe5ac0b160fd43d58011c48a9c`
実装ブランチ: `feature/dya-studio-full-support`

## 参照先

- `origin`: `https://github.com/umecchi1098/zmk-keyboard-torabo-tsuki-lp`
- `upstream`: `https://github.com/sekigon-gonnoc/zmk-keyboard-torabo-tsuki-lp.git`
- 公式派生 `origin/v0.3+dya-studio`: `0e8625d1bb26de8ea6f9a22698f8b8088e6b5346`
- DYA Studio: 安定版WebアプリとDeveloper Guideを2026-08-12時点の対象とする。実装開始時に再確認する

## ローカルビルド環境

- WSL2上のDocker Engine: `28.1.1`
- Docker Compose: `2.35.1`
- イメージ: `zmkfirmware/zmk-dev-arm:3.5`
- イメージdigest: `sha256:9dd48f05e5c9d3311057d114fd719d8a9dc43a5648b6fd572829b2ba05e0cd04`
- West: `1.2.0`
- CMake: `3.30.0`
- Ninja: `1.11.1`
- Python: `3.12.3`
- Zephyr SDK: `0.16.3`

主要依存コミット:

| Project | Revision | Commit |
|---|---|---|
| zmk | `v0.3` | `edf5c0814fd3ea202e43aad2d68fd32e882a518c` |
| zephyr | `v3.5.0+zmk-fixes` | `dacab4875df72109b96cc8977547a0dc04875bcd` |
| zmk-component-bmp-boost | `v0.2` | `8b15ecbb43efe9095e21f5b26fef157faa816f6b` |
| zmk-feature-status-led | `main` | `572d0e16ecdd6b6d57e96461643cc55e7b9164d3` |
| zmk-driver-paw3222 | `torabo-tsuki` | `0e1835c57f88d215ce401b6d0901f361629621fc` |
| zmk-driver-iqs7211e | `master` | `436d3c42172abf812ec104521f29384fc02fc50e` |
| zmk-feature-cdc-acm-bootloader-trigger | `v0.2` | `3fc210f840433bb9204a510f3a2c78b4fa11482f` |
| zmk-feature-non-lipo-battery-management | `main` | `bf024bb7872917f718a960d804136db5f9b88a31` |

`main`／`master`参照は可変である。DYA移行時には採用コミットを固定し、CIと実機確認で再検証する。

## 有効な成果物

| 成果物 | Board | Shield | Snippet |
|---|---|---|---|
| `torabo_tsuki_lp_left_peripheral` | `bmp_boost` | `torabo_tsuki_lp_left` | `studio-rpc-usb-uart` |
| `torabo_tsuki_lp_right_central` | `bmp_boost` | `torabo_tsuki_lp_right` | `studio-rpc-usb-uart split-central input-trackball input-listener` |
| `settings_reset-bmp_boost-zmk` | `bmp_boost` | `settings_reset` | なし |

## 生成結果

ローカルDockerで3成果物をクリーンビルド済み。ファイルは `.build/local/baseline/` に保存し、Git管理対象外とする。

| 成果物 | UF2 | Flash | RAM | SHA-256 |
|---|---:|---:|---:|---|
| 左Peripheral | 359,936 B | 179,904 B | 38,132 B | `063a94cc6e71b1f936df4a86ad71c585ac89a1a751a81627d1abeeb6aee2e518` |
| 右Central | 527,360 B | 263,520 B | 72,602 B | `8c91c9c5e4654eaa2d7de5c5f269f40d6ac834cc0d437668ebdffbe3895a19d9` |
| Settings Reset | 96,256 B | 47,964 B | 11,856 B | `c88e58ae51bfa83196bddf4f06b60d058adc1d8035d53d0316eabaece54c8e5f` |

各成果物について、ビルドログ、Kconfig、生成Devicetreeも保存済み。CIのクリーンビルドは未実施であり、最終的なベースライン合格はCI成功後とする。

## 構成ファイル

ビルド時のキーマップは `boards/shields/torabo_tsuki_lp/torabo_tsuki_lp.keymap`。`config/keymap.keymap` ではない点に注意する。

主要ファイルのSHA-256:

| ファイル | SHA-256 |
|---|---|
| `config/west.yml` | `445b3e8c43eac9d0ac0c1ee39e00764497560fe3535ba628b0492aecef1752d9` |
| `boards/shields/torabo_tsuki_lp/torabo_tsuki_lp.keymap` | `16f70f04b5d8301b93a14021a5bf1f7677bb0a0332438014ed34ad1f6d27c68b` |
| `boards/shields/torabo_tsuki_lp/torabo_tsuki_lp_left.conf` | `493b223cd3b0a80914e32c439a12fbdcb69cc55b828ae4307f12866b6a805420` |
| `boards/shields/torabo_tsuki_lp/torabo_tsuki_lp_left.overlay` | `3e8cbc33048b4b2658c2140db65e3416e5063d6d473e6f61da942f1e9a330273` |
| `boards/shields/torabo_tsuki_lp/torabo_tsuki_lp_right.conf` | `eec6f0df9aa47fbf708378347fe019c773d156be7437269e6493dee0e4fe718d` |
| `boards/shields/torabo_tsuki_lp/torabo_tsuki_lp_right.overlay` | `2acde53706aca9f3234f0c4f460a1f48cef7ca604d33137562bb70c4439664ed` |
| `snippets/split-central/split-central.conf` | `28ba8e0beee63dd9799d95360187597bf0b8e0ef79bbc7359676a4a155aa3852` |
| `snippets/input-trackball/input-trackball.overlay` | `2900c584354dcde5fbd69f2d09a26c68d13a5a7f7d6a51cda6546d855021e583` |
| `zephyr/module.yml` | `a24b5086fc74d2c61784b0ec3e15156de8b05ffc97f1bd248939a2109e77694e` |

## 既存警告

ビルドは成功しているが、次の警告をベースラインとして記録する。

- 左PeripheralでCentral専用設定が無効化されるKconfig警告
- `NRF_STORE_REBOOT_TYPE_GPREGRET` の非推奨警告
- 右Centralの `input_processor_temp_layer.c` に未使用変数と書式指定の警告
- Settings Resetの空キーマップに起因する配列境界警告
- PAW3222のDevicetree vendor prefix警告

DYA移行に伴う新規警告と、上記の既存警告を区別する。

## 回帰チェックリスト

- [ ] Mレイアウトと52キーの位置が維持される
- [ ] 既存7レイヤーとConditional Layerが維持される
- [ ] 左右分割通信と右Central／左Peripheral構成が維持される
- [ ] PAW3222、IQS7211E、Auto Mouse、Scrollが維持される
- [ ] 左右クリック、MB4、MB5が維持される
- [ ] USB、Bluetooth、Sleep復帰が維持される
- [ ] Status LED、Bootloader Trigger、非LiPo電池管理が維持される
- [ ] ZMK Studioの既存キーマップ編集が維持される
