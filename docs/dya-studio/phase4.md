# フェーズ4 Custom Studio Protocolコアの検証記録

確認日: 2026-08-12
対象ブランチ: `feature/dya-studio-full-support`

## 目的

DYA Studio固有機能が、型付きの設定を安全に読み書きできる共通基盤を追加する。

右CentralはUSB経由のCustom Settings RPCを受け付ける。左PeripheralはStudio RPCを直接持たず、左右間のSplit Relayだけを使って設定要求と応答を右Centralへ中継する。

## 採用した依存

| Module | 採用コミット | 用途 |
| --- | --- | --- |
| `zmk-feature-custom-settings` | [`c6a7fef3a3be3d3ace5de9a4b0628c6418cd1f3f`](https://github.com/cormoran/zmk-feature-custom-settings/commit/c6a7fef3a3be3d3ace5de9a4b0628c6418cd1f3f) | 型・権限・保存操作を備えた設定管理と、左右間のRPC中継 |

可変ブランチではなく、上流テストが成功している確認済みコミットSHAへ固定した。

## 実装内容

### 左右共通

- Custom SettingsコアとSplit Relayを有効化
- 後続フェーズで使うLarge Values、Array、Keyspace、RPC Converter、Recordを明示的に有効化
- Split Relayのデータ長を現行DYA2と同じ240バイトに設定
- 設定保存デバウンスを10秒に設定

Split Relayは管理用に2バイトを使うため、1回で中継できる実データは238バイトである。右Central側では256バイトの大きな値を扱えるが、238バイトを超える単一データを左Peripheralへそのまま中継する用途には使わない。診断機能を追加するフェーズ8で、KSCAN Diagnosticsの現行仕様に合わせて再評価する。

### 左Peripheral

- Custom SettingsのSplit Relayだけを有効化
- ホストと通信するStudio RPCは無効のまま維持
- 低優先度スレッドのスタックを2,048バイトに設定

### 右Central

- Custom Settings Studio RPCを有効化
- RPC受信・送信・Custom subsystem payloadを256バイトに設定
- Large Value上限を256バイトに設定
- Split処理、低優先度処理、System Workqueue、Studio RPCの各スタックを現行DYA2の実績値へ拡張

本番版はStudio Lockを有効、開発版だけ無効というフェーズ3の分離を維持した。

## 設定操作の方針

後続フェーズで設定項目を登録する際は、次の意味を共通ルールとする。

| 操作 | 動作 | 利用場面 |
| --- | --- | --- |
| Memory | RAM上の値だけを変更する。再起動すると保存済みの値へ戻る | 動作を一時的に試す |
| Save | 現在値を永続化する。Flashへの実書き込みは変更後10秒にまとめる | 採用する値を保存する |
| Discard | 未保存の変更を捨て、直前に保存した値を読み直す | 試した変更を取り消す |
| Reset | 既定値へ戻し、該当する保存値を削除する | 設定項目だけを初期化する |

設定全体を初期化する場合は、従来どおりSettings Reset成果物を使う。Custom Settingsの中継がある通常ファームウェアでは、後続フェーズで登録するPeripheral設定も一括初期化の対象にできる。

## セキュリティ方針

フェーズ4は通信と設定管理の基盤だけを追加し、ユーザーが変更する具体的な設定項目はまだ登録しない。

後続フェーズで追加する設定は、次の方針で項目ごとに権限を指定する。

- 設定一覧や安全な公開情報の読み取りは、必要な範囲だけロック中も許可する
- 機器状態を詳しく公開する値や個人情報になり得る値は、読み取りにもUnlockを要求する
- 動作や保存内容を変更する書き込み、Save、Discard、Resetは、本番版でUnlockを要求する
- 開発版は切り分け用途に限定し、通常運用には使わない

Studio Lockを迂回する独自の書き込み経路は追加しない。

## ローカル検証結果

`./scripts/zmk-build.sh dya` で4成果物をクリーンビルドし、すべて成功した。

| 成果物 | text | data | BSS | UF2 | SHA-256 |
| --- | ---: | ---: | ---: | ---: | --- |
| 左Peripheral | 196,652 B | 23,600 B | 70,887 B | 440,832 B | `dba63e549db46ab9f45e7d9a41674a4d0056a817e63ffd4fc0a2e3de065b03b6` |
| 右Central本番版 | 270,848 B | 50,679 B | 123,928 B | 643,072 B | `11df32acf9a3a0c69b450e380cccd13bffc5d81d6e28c7b3863811029c4893f4` |
| 右Central開発版 | 270,756 B | 50,632 B | 123,927 B | 643,072 B | `a829c5b838dbb3ddcbc9ab17569f19ab0a3a8545b98324f125b17ed963b3cc21` |
| Settings Reset | 50,808 B | 3,837 B | 12,179 B | 109,568 B | `1481398b551dd7b1032c9d86b2966ba579b77cac3b1302fad95203727221cfeb` |

### フェーズ3とのサイズ比較

| 成果物 | text差 | data差 | BSS差 | Flash使用率 | RAM使用率 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 左Peripheral | +18,532 B | +2,584 B | +32,511 B | 30.21% | 28.58% |
| 右Central本番版 | +18,736 B | +4,312 B | +46,261 B | 44.10% | 49.72% |
| 右Central開発版 | +18,740 B | +4,312 B | +46,261 B | 44.08% | 49.70% |
| Settings Reset | 0 B | 0 B | 0 B | 7.50% | 5.02% |

Custom SettingsのRPC、型変換、一時領域、キュー、スタックにより使用量は増えた。最も大きい右CentralでもFlashは44.10%、RAMは49.72%で、後続機能を追加できる余裕がある。各フェーズで継続して監視する。

## 生成物の検査

- 左右ともCustom Settingsコア、Split Relay、将来使用する設定型が有効
- 左PeripheralではCustom Settings Studio RPCが無効
- 右Central本番版・開発版ではCustom Settings Studio RPCが有効
- Split Relayデータ長は左右とも240バイト
- 本番版だけStudio Lockが有効
- Fast Keymap、Default Layer読取、Physical Layout RPCを維持
- 独自左右間BLE省電力処理は無効のまま
- ZMK標準Idle 30秒／Deep Sleep 150分を維持
- DeviceTreeはフェーズ3の4対象と完全一致
- Settings ResetのUF2はフェーズ3と完全一致

## 上流テスト

固定したCustom Settingsモジュールの公式テストを、同じZephyr 4.1 Docker workspaceで実行した。

```text
python3 -m unittest -v
Ran 2 tests in 66.794s
OK
```

このテストには、6種類の機能構成ビルドと、Custom Settingsの処理を確認するZMKテスト群が含まれる。固定先コミットの上流CIでは、wired split relayのRenodeテストも成功している。

## 警告の確認

今回変更したリポジトリ内コードに新規コンパイラ警告はない。

左Peripheralでは、固定した上流Custom Settingsモジュールの共通ハンドラー内にあるStudio RPC用関数が未使用になる警告が発生する。これはPeripheralへStudio RPCをリンクしない役割分離によるもので、上流テストと本リポジトリのビルドは成功している。

そのほかはフェーズ3までに確認済みのKconfig非推奨警告、DYA向けZMK、Fast Keymap、Settings Resetの上流警告である。

## 実機確認

フェーズ4は基盤だけを追加し、DYA Studioに新しいユーザー設定画面はまだ増えない。DeviceTreeも完全一致しているため、このフェーズ単独の実機書き込みは不要とし、Macro・Combo・Input Streamを追加するフェーズ5でまとめて確認する。

## CI確認結果

コミット後にGitHub Actionsで4成果物をクリーンビルドし、ローカル成果物とのSHA-256一致を確認する。
