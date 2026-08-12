# フェーズ3 ZMK Studioレベル1の検証記録

確認日: 2026-08-12
対象ブランチ: `feature/dya-studio-full-support`

## 目的

DYA Studioから既存キーマップを安全に閲覧・編集できる基盤を完成させる。

通常運用する本番版はStudio Lockを有効にし、キーボード側で明示的に解除した場合だけ変更を許可する。開発・診断時だけ使うLock無効版は、別の成果物として明確に分離する。

## 現行仕様の確認

2026-08-12時点で次を再確認した。

- [DYA Studio安定版](https://studio.dya.cormoran.works)
- [DYA Studio公式リポジトリ](https://github.com/cormoran/dya-studio)
- [DYA2参照ファームウェア](https://github.com/cormoran/zmk-keyboard-dya2)
- [ZMK Studio公式ガイド](https://zmk.dev/docs/features/studio)
- [ZMK Studio Lock公式設定](https://zmk.dev/docs/config/studio)
- [Studio Unlock behavior](https://zmk.dev/docs/keymaps/behaviors/studio-unlock)

DYA Studio安定版はChrome／EdgeのWeb Serialを使うUSB接続に対応している。一般的なZMK Studio対応キーボードではキーマップ編集が利用でき、DYA独自の各画面は対応モジュールを後続フェーズで追加すると順次利用可能になる。

DYA2参照実装と同じく、既存レイヤーの末尾へReserved Layerを4層確保した。追加モジュールは可変ブランチではなく、確認済みコミットSHAへ固定した。

| Module | 採用コミット | 用途 |
| --- | --- | --- |
| `zmk-feature-fast-keymap` | `8dac76de0ba38588ba39ca498910e24f8332bc6b` | 既定キーマップとの差分を高速に読み取る |
| `zmk-feature-module-physical-layout` | `4f18de45dc27820725d267916b4cdacc0e0b6cf9` | キー以外の物理デバイス位置を通知する |

Fast Keymapは読み取り専用で、キーマップの書き込み経路やStudio Lockを迂回しない。

## 実装内容

- 右Central本番版でStudio Lockを既定どおり有効化
- Adjustレイヤーの左上キーへ `&studio_unlock` を追加
- Base～Adjustの既存7レイヤーの後ろへReserved Layerを4層追加
- Mレイアウトの52位置mapを完全なmapとして明示
- Fast Keymap RPCとDefault Layer読取を右Centralで有効化
- Physical Layout RPCを右Centralで有効化
- 使用中のsnippetに応じて、トラックボールまたはトラックパッドの物理表示nodeを有効化
- Custom Studio RPC受信バッファを推奨値の128バイトへ拡張
- Studio Lockだけを無効化した右Central開発版を追加
- CIの成果物数検査を `build.yaml` の有効項目数から自動算出する方式へ変更
- 外部Physical Layoutモジュールが使う `cormoran` vendor prefixをZephyrへ登録

## 成果物の使い分け

| 成果物 | 用途 | Studio Lock |
| --- | --- | --- |
| `torabo_tsuki_lp_left_peripheral.uf2` | 左Peripheralの通常版 | 対象外 |
| `torabo_tsuki_lp_right_central.uf2` | 右Centralの本番版・通常運用 | 有効 |
| `torabo_tsuki_lp_right_central_develop.uf2` | 開発・切り分け専用 | 無効 |
| `settings_reset-bmp_boost-zmk.uf2` | 設定初期化 | 対象外 |

開発版は常時編集可能になるため、通常運用では使用しない。

## ローカル検証結果

`./scripts/zmk-build.sh dya` で4成果物をクリーンビルドし、すべて成功した。

| 成果物 | text | data | BSS | UF2 | SHA-256 |
| --- | ---: | ---: | ---: | ---: | --- |
| 左Peripheral | 178,120 B | 21,016 B | 38,376 B | 398,336 B | `7c03494efd06c8d8f8676f5323ec51dd74c3d85db2ee27fc51d105d8fded14c6` |
| 右Central本番版 | 252,112 B | 46,367 B | 77,667 B | 596,992 B | `84ad81a2127448fc5a111ce02cef7ee2e184c00fda489cfe2b58e12a18dcbcec` |
| 右Central開発版 | 252,016 B | 46,320 B | 77,666 B | 596,992 B | `c2103f1b61488fc3e1160ce366f3195db57e6be71495300ab9c663d6187a45d3` |
| Settings Reset | 50,808 B | 3,837 B | 12,179 B | 109,568 B | `1481398b551dd7b1032c9d86b2966ba579b77cac3b1302fad95203727221cfeb` |

Settings Resetはフェーズ2のバイナリと完全一致した。右Central本番版と開発版のサイズ差はStudio Lockの有無によるもので、本番版でもFlashとRAMには十分な余裕がある。

## CI確認結果

[GitHub Actions run `31600347535`](https://github.com/umecchi1098/zmk-keyboard-torabo-tsuki-lp/actions/runs/31600347535) が成功した。

- クリーン環境からWest workspaceを初期化: 成功
- 左Peripheral、右Central本番版、右Central開発版、Settings Resetのビルド: 成功
- `build.yaml` から算出した期待数4件とUF2収集数の一致: 成功
- `firmware` artifactの作成: 成功

CI成果物4件をダウンロードし、上表のローカル成果物とSHA-256が完全一致することを確認した。以降の実機確認では、このrunの `firmware` artifactを正とする。

### 生成物の検査

- 本番版: `CONFIG_ZMK_STUDIO_LOCKING=y`
- 開発版: `CONFIG_ZMK_STUDIO_LOCKING` 無効
- 両右Central: Fast Keymap、Default Layer読取、Physical Layout RPCが有効
- 既存レイヤー0～5: フェーズ2と完全一致
- Adjustレイヤー: 左上の `&trans` を `&studio_unlock` へ変更した1点以外は完全一致
- Reserved Layer: 既存レイヤー6の後ろに4層存在
- M Physical Layout: 52位置が順番どおり完全に対応
- Conditional Layer: `MID + RAISE -> ADJUST` を維持
- Bluetoothクリアコンボと既存input processor chainを維持
- 独自左右間BLE省電力処理は無効のまま
- ZMK標準Idle 30秒／Deep Sleep 150分を維持
- Settings Resetはフェーズ2とUF2が完全一致

## 警告の確認

新たなPhysical Layout nodeで発生した未登録vendor prefix警告は、このリポジトリのZephyr moduleへprefixを登録して解消した。

残る警告はフェーズ1・2から存在するものと、固定した上流DYAモジュール内の警告である。今回変更したキーマップ、レイアウト、設定コードに新規コンパイラ警告はない。

- 既存のPeripheral向けKconfig依存警告
- 既存の `KSCAN`／`BT_CTLR` 非推奨警告
- 既存のSettings Reset空キーマップ配列警告
- DYA向けZMKの既存ポインター処理警告
- Fast KeymapとCustom Studio Protocolの固定済み上流ソース警告

## ユーザー実機確認 — 必須ゲート

GitHub Actions成功後、CI成果物の本番用右Centralだけを書き込んで確認する。左右間通信の方式とキー位置番号は変えておらず、左Peripheralは位置情報を右Centralへ送る従来構成のままなので、今回は左側の再書き込みは不要。

### 書き込み対象

```text
torabo_tsuki_lp_right_central.uf2
```

`torabo_tsuki_lp_right_central_develop.uf2` はLock切り分け専用なので、通常の確認には使わない。

### 確認手順

1. ChromeまたはEdgeで[DYA Studio安定版](https://studio.dya.cormoran.works)を開く。
2. 右CentralをUSB接続し、DYA Studioの「USB」からシリアルポートを選ぶ。
3. Keymap画面で、Mレイアウト、既存7レイヤー、トラックボール表示を確認する。
4. 接続直後のロック状態で、変更操作が拒否またはロック表示になることを確認する。
5. キーボードで `Mid + Raise` を同時に有効にしてAdjustレイヤーへ入る。
6. Adjustレイヤー左上、通常はBaseレイヤーでTabになるキーを1回押してUnlockする。
7. 重要でない1キーを別キーへ変更して保存し、そのキー入力が変わることを確認する。
8. USBを抜き差しまたはキーボードを再起動し、変更が保持されていることを確認する。
9. DYA Studioで変更したキーを元の割り当てへ戻して保存する。
10. 1分以上無操作にした後、左側キー入力とトラックボールが引き続き動作することを確認する。

Studio Lockは切断時に再ロックされ、解除状態も無操作10分で終了する。解除キーは押した瞬間に動作し、長押しは不要。

## 現在の制約

フェーズ3で使用できる中心機能はキーマップ編集、レイヤー編集、Physical Layout表示である。Macro、Combo、Input Stream、ポインター設定、接続管理、本体設定、診断などのDYA独自機能は、フェーズ4以降で対応モジュールを追加するまで利用対象外とする。

## 実機確認結果

2026-08-12、ユーザーがCI成果物の本番用右Centralを使用し、DYA Studioで次を確認した。

- Studio Lock中は編集が保護される
- AdjustレイヤーのUnlockキーでロックを解除できる
- キーマップ変更を保存できる
- M Physical Layout上のトラックボール表示と、実機のトラックボール動作に問題がない

接続安定化設定を含む通常運用にも問題がないため、フェーズ3の必須ゲートは合格とする。
