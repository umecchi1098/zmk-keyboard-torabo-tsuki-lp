# フェーズ5 Macro・Combo・Input Streamの検証記録

確認日: 2026-08-12  
対象ブランチ: `feature/dya-studio-full-support`

## 目的

DYA StudioからRuntime MacroとRuntime Comboを作成・保存し、Input Streamで押下位置とレイヤー変更を確認できるようにする。

既存の7レイヤー、Bluetooth Clearコンボ、左右分割通信、ポインター処理は維持する。本番版はStudio Lockを有効にし、新しい編集・監視機能をUnlock後だけ利用できる構成とする。

## 採用した依存

| Module | 採用コミット | 用途 |
| --- | --- | --- |
| `zmk-feature-runtime-macro` | [`38530962eb7061b60efcb98e84585cfb1f0cb6de`](https://github.com/cormoran/zmk-feature-runtime-macro/commit/38530962eb7061b60efcb98e84585cfb1f0cb6de) | Macroの作成、編集、保存、実行 |
| `zmk-feature-runtime-combo` | [`d9490e7b5d41c516221d131241009e81740efcee`](https://github.com/cormoran/zmk-feature-runtime-combo/commit/d9490e7b5d41c516221d131241009e81740efcee) | 実行時Comboの作成、編集、保存 |
| `zmk-feature-input-stream` | [`aeb015908a42a7615ccdccc7feb3a10d23132a71`](https://github.com/cormoran/zmk-feature-input-stream/commit/aeb015908a42a7615ccdccc7feb3a10d23132a71) | 押下位置とレイヤー変更の表示 |

可変ブランチではなく、FirmwareテストとWeb UIテストが成功したコミットSHAへ固定した。

## 実装内容

### Runtime Macro

- Macro数: 8個
- Macro名: UTF-8で最大24バイト（終端NULを除く）
- 共有pool: 1,024バイト
- 1個のMacro: 最大256バイト
- 実行queue: 64 action
- 既定tap時間: 30ms
- キーへ割り当てるbehavior: `&rmacro <slot>`

新規状態ではMacroを1個も作成しない。空slotを割り当てても入力は発生せず、DYA Studioで作成したMacroだけを明示的に利用する。

### Runtime Combo

- Runtime Combo数: 8個
- 1個に使える位置: 最大16キー
- 既定timeout: 50ms
- 既定require-prior-idle: 0ms（無効）
- 既定Runtime Combo: なし

既存のBluetooth Clearコンボは、従来のDevicetreeによるCompile-time Comboとして変更せず維持する。Runtime Comboは追加枠として動作する。

### Input Stream

本番版と開発版の両方で有効にした。ユーザーがDYA Studioから明示的に開始した間だけ、物理キーの押下・解放と最上位レイヤーの変更を通知する。

固定した上流版には、配信中にUSBを切断するとストリーム状態が残る既知の制約がある。DYA Studioで必ずInput Streamを停止してから、USBケーブルを抜くかDYA Studioを切断する。

## Studio Lockの保護

Runtime Macroは、ロック中の一覧表示だけを許可し、内容の取得・編集・保存には上流実装がUnlockを要求する。Input Streamは上流実装でsubsystem全体がSecureになっている。

固定したRuntime Combo上流版は、Custom Settings側の書き込み権限をSecureに設定している一方、独自RPC subsystemをUnsecuredとして登録していた。独自RPCが汎用Custom Settingsの権限検査を通らないため、そのままではStudio Lockを迂回して編集できる。

このキーボードでは、起動時にRuntime Combo subsystem全体をSecureへ変更するフェイルセーフを追加した。最初にSecureへ変更してから固定識別子を検査し、上流の公開symbolも直接参照する。識別子が変わった場合もSecure状態を維持し、symbolが変わった場合はリンクを失敗させるため、意図せず無保護にはならない。本番版では一覧表示を含め、Runtime Combo画面の利用にUnlockが必要である。

## Behavior IDの移行

MacroとComboが参照するbehavior IDを、登録順に依存するSettings Table形式からCRC16形式へ変更した。今後の機能追加でbehaviorの登録順が変わっても、保存済みMacro／Comboが別behaviorを指しにくくなる。

この変更以前に保存したDYA Studioのキーマップoverrideは、古いlocal IDを含む可能性がある。フェーズ5の初回書き込み時だけ、右CentralへSettings Resetを書き込んで保存設定を消去してから、本番版ファームウェアを書き込む。Bluetooth pairingも消えるため、使用するprofileを再ペアリングする。

## RPCと保存領域

- Custom subsystem request payload: 256バイト
- Runtime Macro最大request: 86バイト
- Runtime Combo最大request: 149バイト
- Input Stream最大request: 2バイト
- RPC RX／TXリングバッファ: 各256バイト

すべての要求は1回でRXバッファへ収まる。Macro詳細やCombo一覧などの大きな応答は、ZMK RPCがTXリングバッファを空けながら逐次エンコード・送信するため、応答全体を256バイト以内へ制限する必要はない。

MacroとComboはCustom Settingsを通じてNVSへ保存される。Settings Reset成果物はsettings partition全体を消去するため、保存したRuntime Macro／ComboとDYA Studioのキーマップoverrideも初期化される。

## ローカル検証結果

`./scripts/zmk-build.sh dya` で4成果物をクリーンビルドし、すべて成功した。

| 成果物 | text | data | BSS | Flash | RAM | UF2 | SHA-256 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 左Peripheral | 196,652 B | 23,600 B | 70,887 B | 30.21% | 28.58% | 440,832 B | `dba63e549db46ab9f45e7d9a41674a4d0056a817e63ffd4fc0a2e3de065b03b6` |
| 右Central本番版 | 283,352 B | 58,623 B | 133,792 B | 46.91% | 54.33% | 684,032 B | `732899eab7885255f4fc87e358f773e47b312955c6320aec5a531872dc6a3c99` |
| 右Central開発版 | 283,260 B | 58,576 B | 133,791 B | 46.89% | 54.31% | 684,032 B | `ad5a3ea5b4a5d8b7b6717b4993c808896a775ddfd440550ff09c6abd23284803` |
| Settings Reset | 50,808 B | 3,837 B | 12,179 B | 7.50% | 5.02% | 109,568 B | `1481398b551dd7b1032c9d86b2966ba579b77cac3b1302fad95203727221cfeb` |

### フェーズ4とのサイズ比較

| 成果物 | text差 | data差 | BSS差 | Flash使用率差 | RAM使用率差 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 左Peripheral | 0 B | 0 B | 0 B | 0.00pt | 0.00pt |
| 右Central本番版 | +12,504 B | +7,944 B | +9,864 B | +2.81pt | +4.61pt |
| 右Central開発版 | +12,504 B | +7,944 B | +9,864 B | +2.81pt | +4.61pt |
| Settings Reset | 0 B | 0 B | 0 B | 0.00pt | 0.00pt |

最も大きい右Central本番版でもFlash 46.91%、RAM 54.33%であり、後続機能を追加できる余裕がある。

## 回帰検査

- 右Central本番版・開発版だけでMacro、Combo、Input Streamを有効化
- 本番版だけStudio Lockを有効化
- Runtime Comboの保護初期化関数と上流subsystem symbolがELFへリンク済み
- 左Peripheralへ各機能の実行コードとStudio RPCをリンクしていない
- Devicetree差分は`rmacro` behavior nodeの追加だけ
- 既存7レイヤーとBluetooth Clearコンボを維持
- 左PeripheralのUF2はフェーズ4と完全一致
- Settings ResetのDevicetreeとUF2はフェーズ4と完全一致
- 独自左右間BLE省電力処理は無効のまま
- ZMK標準Idle 30秒／Deep Sleep 150分を維持
- 今回変更したリポジトリ内コードに新規コンパイラ警告なし

## 上流テスト

固定した各モジュールの公式Firmwareテストを、同じZephyr 4.1 Docker workspaceで実行した。

| Module | Firmwareテスト | Web UIテスト |
| --- | --- | --- |
| Runtime Macro | 2件成功 | 3 suites／16 tests成功 |
| Runtime Combo | 2件成功 | 2 suites／8 tests成功 |
| Input Stream | 2件成功 | 2 suites／8 tests成功 |

Firmwareテストにはモジュール固有のunit testと構成ビルドが含まれる。Web UIは`npm ci`、protobuf生成、Jestを順に実行した。Runtime ComboとInput StreamではReactの`act(...)`警告が表示されるが、テスト失敗はない。

固定したCustom Studio Protocol共通macroに、応答bufferのsequence値を`void *`として加算する上流警告がある。3機能と既存Custom Settings／Physical Layoutで共通して発生するが、モジュール公式テストと本リポジトリの全ビルドは成功している。

## 初回書き込みと実機確認

local IDをCRC16へ移行するため、今回は次の順番を守る。

1. 右Centralへ`settings_reset-bmp_boost-zmk.uf2`を書き込む。
2. 右Centralへ`torabo_tsuki_lp_right_central.uf2`を書き込む。
3. Bluetoothを利用する場合は、使用profileを再ペアリングする。
4. 左Peripheralはフェーズ4とバイナリが同一のため、書き換え不要。
5. USBでDYA Studioへ接続し、ロック中にMacroの内容取得・編集、Runtime Combo画面、Input Stream開始が拒否されることを確認する。
6. AdjustレイヤーのStudio Unlockを押し、Runtime Macroを作成して未使用キーへ`&rmacro <slot>`を割り当て、実行できることを確認する。
7. Macroを保存し、再起動後も復元・実行できることを確認する。
8. Runtime Comboを作成・保存し、指定した同時押しで実行できることを確認する。
9. 既存Bluetooth Clearコンボが従来どおり動作することを確認する。実行するとpairingが消えるため、必要なprofileを再ペアリングする。
10. Input Streamを開始し、押下位置とレイヤー変更が表示されることを確認する。
11. **Input Streamを停止してから**DYA Studioを切断する。
12. テスト用Macro／Comboを削除して保存する。

実機確認が完了するまで、フェーズ5は完了扱いにしない。

## CI確認結果

[GitHub Actions run `31609107142`](https://github.com/umecchi1098/zmk-keyboard-torabo-tsuki-lp/actions/runs/31609107142) が成功した。

- クリーン環境からWest workspaceを初期化: 成功
- 左Peripheral、右Central本番版、右Central開発版、Settings Resetのビルド: 成功
- `build.yaml`から算出した期待数4件とUF2収集数の一致: 成功
- `firmware` artifactの作成: 成功

CI成果物4件をダウンロードし、上表のローカル成果物とSHA-256およびバイナリ内容が完全一致することを確認した。
