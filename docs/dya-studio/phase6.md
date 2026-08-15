# フェーズ6 Runtime Input Processor移行の検証記録

確認日: 2026-08-15
対象ブランチ: `feature/dya-studio-full-support`

## 目的

従来の固定ポインター処理をRuntime Input Processorへ移行し、DYA Studioから感度、回転、反転、自動Mouseレイヤー、Scroll設定を変更・保存できるようにする。

既存の安定した配布構成は、トラックボールを搭載した右Centralだけがポインター入力を処理する片側版である。この構成は変えず、左右両方へポインターを搭載する構成を明示的な`double_ball`成果物として追加した。

## 採用した依存

| Module | 採用コミット | 用途 |
| --- | --- | --- |
| `zmk-module-runtime-input-processor` | [`43618985f8c9d5457cc333b7ca0733f2d361911e`](https://github.com/cormoran/zmk-module-runtime-input-processor/commit/43618985f8c9d5457cc333b7ca0733f2d361911e) | ポインター設定の実行時変更、保存、DYA Studio UI |

可変ブランチではなく、FirmwareテストとWeb UIテストが成功しているコミットSHAへ固定した。保存基盤はフェーズ4で固定済みの`zmk-feature-custom-settings`を使用する。

## 配布構成と入力経路

| 構成 | 左Peripheral | 右Central | Runtime Processorの実行場所 |
| --- | --- | --- | --- |
| 標準片側版 | キー入力のみ | ローカルのPAW3222／IQS7211E | 右Central |
| `double_ball`版 | PAW3222の生入力をSplit送信 | ローカル入力と左Split入力 | 右Central |

標準版は従来の書き込み先と役割を維持する。`double_ball`版だけ、左へ`input-trackball`と`input-split`、右へ`input-split-listener`を追加する。左PeripheralにはRuntime ProcessorやStudio RPCを組み込まない。キー入力のSplit通信と、フェーズ1で無効化した独自BLE省電力処理は変更していない。

## Processorの既定値

| DYA Studio表示名 | 対象構成 | 入力 | 感度 | 反転 | 自動Mouse | Scroll対象 |
| --- | --- | --- | --- | --- | --- | --- |
| `mouse` | 標準／`double_ball` | 右ローカル | `1/1` | X・Y | Layer 1、開始待ち150ms、解除500ms | なし |
| `scroll` | 標準／`double_ball` | 右ローカル | `1/64` | Xのみ | 無効 | Layer 5 |
| `lmouse` | `double_ball`のみ | 左Split | `1/1` | X・Y | Layer 1、開始待ち150ms、解除800ms | なし |
| `lscroll` | `double_ball`のみ | 左Split | `1/64` | Xのみ | 無効 | Layer 5 |

Mouseレイヤー1のクリック・Middle・Scrollキーは透明ではないため、操作中はRuntime Input Processorの一時レイヤー解除判定から除外される。これは旧`excluded-positions = <19 20 21 22>`と同じ結果になる。

## 旧process-nextの再現

LocalとSplitの両方で、Processorを次の順に登録した。

```text
Scroll → Mouse
```

Layer 5ではScrollがXYコードをWheelコードへ変換するため、後段のMouseは対象外として通過する。Layer 5以外ではScrollが何も変更せず、MouseがXY反転と自動Mouseレイヤーを処理する。この順序により、旧scroller childの`process-next`と同じイベント処理を維持する。

旧`auto_mouse_layer`、`zip_xy_transform`、`zip_xy_scaler`、`zip_xy_to_scroll_mapper`によるポインターchainは生成Devicetreeから削除した。

## DYA Studioの保存操作

標準版の2設定、または`double_ball`版の4設定は、右CentralのCustom Settingsへ個別に保存される。左用設定も実行・保存場所は右Centralであり、左PeripheralのFlashへは保存しない。

| 操作 | 結果 |
| --- | --- |
| Memory | 再起動までRAM上で試す |
| Save All | 現在の設定を右CentralのFlashへ保存する |
| Discard All | 未保存変更を破棄し、保存値またはDevicetree既定値へ戻す |
| Reset All | 設定をDevicetree既定値へ戻して保存する |

保存blobはバージョン番号と固定サイズをFirmware側で検査する。不一致の場合は保存値を適用せず、Devicetree既定値を維持する。

## Studio Lockの保護

固定した上流版は、Runtime Input Processor専用RPCと、保存blobを公開する汎用Custom Settings RPCをUnsecuredとして登録している。

このキーボードでは、起動時に次の2 subsystemをSecureへ変更するフェイルセーフを追加した。

- `cormoran_rip`
- `cormoran_custom_settings`

最初にSecureへ変更してから固定識別子を検査する。上流symbolが変わった場合はリンクを失敗させ、識別子が変わった場合も無保護のまま起動しない。本番版では一覧取得、設定変更、Save、Discard、ResetのすべてにStudio Unlockが必要である。開発版だけは従来どおりStudio Lockを無効にしている。

## 上流の数値検査に関する制約

DYA Studio公式UIは回転、レイヤー、待ち時間、軸設定などの入力範囲を制限する。一方、固定した上流Firmwareは、独自に細工したRPC要求のすべての数値範囲を完全には拒否しない。

通常運用では次を守る。

- 本番版を使用する
- Adjustレイヤーから明示的にUnlockする
- DYA Studio公式UIだけで変更する
- Custom Settingsのraw blobを直接編集しない

専用RPCとraw blob経路の両方をUnlock必須にしたため、Lock中に細工した値を書き込む経路は閉じている。Firmware単体での完全な数値範囲拒否は、上流修正を追跡する課題として残す。

## 自動検証

`./scripts/zmk-build.sh dya`で6成果物をクリーンビルドし、すべて成功した。

GitHub Actions run `31857296764`でもクリーンビルドに成功した。CIから取得した6成果物は、次表のローカル成果物とSHA-256で完全一致した。

| 成果物 | text | data | BSS | Flash | RAM | UF2 | SHA-256 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 標準 左Peripheral | 196,260 B | 23,474 B | 70,887 B | 30.14% | 28.58% | 439,808 B | `5179dfb912266f9fee65124ef61e807d9eeb355662b2d6415bdf807887b0098e` |
| 標準 右Central本番版 | 294,772 B | 62,247 B | 133,974 B | 48.97% | 54.40% | 714,240 B | `76294c31c121895698d4be919652dfa945b9713bd8ed4b0e7234b9936f915db4` |
| 標準 右Central開発版 | 294,676 B | 62,200 B | 133,973 B | 48.95% | 54.38% | 714,240 B | `2fa63a2d8786b705e71cc88d5d4333fe88ad663c6d4847e23e0c6b4c0874947b` |
| `double_ball` 左Peripheral | 202,868 B | 24,030 B | 71,051 B | 31.12% | 28.71% | 454,144 B | `178082481dc2abd25862e22b76f306b1997eba9b2a90364fbce90ef744077d73` |
| `double_ball` 右Central | 295,768 B | 63,089 B | 134,714 B | 49.22% | 54.71% | 717,824 B | `4f651ec236d55d0317333645e2bd8ea44523b0df27a4cb3dd58c302dfe4c8561` |
| Settings Reset | 50,808 B | 3,837 B | 12,179 B | 7.50% | 5.02% | 109,568 B | `1481398b551dd7b1032c9d86b2966ba579b77cac3b1302fad95203727221cfeb` |

### フェーズ5とのサイズ比較

| 標準成果物 | text差 | data差 | BSS差 | Flash使用率差 | RAM使用率差 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 左Peripheral | -392 B | -126 B | 0 B | -0.07pt | 0.00pt |
| 右Central本番版 | +11,420 B | +3,624 B | +182 B | +2.06pt | +0.07pt |
| 右Central開発版 | +11,416 B | +3,624 B | +182 B | +2.06pt | +0.07pt |
| Settings Reset | 0 B | 0 B | 0 B | 0.00pt | 0.00pt |

左Peripheralの小さな減少は、標準版では使われていなかった旧ポインターProcessor定義を削除したためである。最大の`double_ball`右CentralでもFlash 50%未満、RAM 55%未満である。

`scripts/check-runtime-input-processors.sh`を追加し、次を生成物から自動検査した。

- 標準左PeripheralにポインタードライバーとSplit送信が入らない
- `double_ball`左PeripheralはSplit送信だけを持ち、Runtime Processorを持たない
- 標準右CentralのProcessor数は2、`double_ball`右Centralは4
- 左右Mouseの150ms、500ms、800ms
- 左右ScrollのLayer 5、X反転、倍率`1/64`
- Local／SplitともScroll→Mouseの順序
- 旧`auto_mouse_layer`と旧Temp Layer Processorが存在しない
- 本番版のStudio Lockと追加保護が有効
- 開発版だけStudio Lockが無効

IQS7211Eの`input-trackpad-mini`とSplit Listenerを同時に有効にした互換構成もビルドに成功した。

## 上流テスト

固定したモジュールのFirmwareテストを同じZephyr 4.1 Docker workspaceで実行し、`PASS: studio`を確認した。テストには保存後の再読込、Memory／Persist／Temporaryの書き込みモード、Runtime Processorを有効／無効にした構成ビルドが含まれる。

Web UIは`npm ci`、protobuf生成、Lint、Jest、production buildを実行した。

- Lint: 成功
- Jest: 1 suite／10 tests成功
- Production build: 成功

JestのブラウザーAPI mock警告、上流Custom Studio Protocol共通macroの警告、bundle size警告はあるが、テスト失敗はない。

`npm audit --omit=dev`では、上流Web UIが使用する`protobufjs`系にmoderate 1件、critical 1件が報告された。このリポジトリはWeb UIを配布せず、Firmwareが上流の公式UI URLをDYA Studioへ通知する構成であるため、ここでは依存を変更できない。公式DYA Studio以外のUIを使用せず、上流更新時に再確認する。

## 実機書き込みと確認

保存形式の移行やbehavior ID変更はないため、Settings Resetは不要である。

### 標準の片側トラックボール構成

右Centralのポインター処理だけが実行時設定へ変わる。左Peripheralには機能・通信方式の変更がないため、通常は右だけを書き換えればよい。

1. トラックボール側へ`torabo_tsuki_lp_right_central.uf2`を書き込む。
2. キー入力、無操作後の左側再接続、ポインター移動を確認する。
3. 自動Mouseレイヤー、Layer 5のScroll方向と速度を確認する。
4. 左右クリック、Middle、MB4、MB5を確認する。
5. DYA Studioへ接続し、Lock中はRuntime Input Processor画面が拒否されることを確認する。
6. AdjustレイヤーのStudio Unlockを押し、`mouse`と`scroll`が表示されることを確認する。
7. Memoryで感度、回転、反転、対象レイヤーを一項目ずつ変更する。
8. Discard Allで保存前の値へ戻ることを確認する。
9. もう一度変更してSave Allを実行し、再起動後も復元されることを確認する。
10. Reset Allで表の既定値へ戻し、再起動後も既定値であることを確認する。

### 左右両方にポインターがある`double_ball`構成

標準版と混在させず、必ず次の2ファイルを組にして書き込む。

1. 左へ`torabo_tsuki_lp_double_ball_left_peripheral.uf2`を書き込む。
2. 右へ`torabo_tsuki_lp_double_ball_right_central.uf2`を書き込む。
3. 標準版の確認に加え、左右を個別に操作する。
4. DYA Studioに`mouse`、`scroll`、`lmouse`、`lscroll`が表示されることを確認する。
5. 左の自動Mouse解除が800ms、右が500msであることを確認する。

## 現在の状態

ローカル実装、6成果物ビルド、生成物検査、上流Firmware／Web UIテスト、GitHub Actionsは完了した。ユーザー実機確認だけを必須ゲートとして残している。
