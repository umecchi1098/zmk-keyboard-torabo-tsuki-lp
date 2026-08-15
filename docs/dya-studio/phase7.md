# フェーズ7 接続管理・Default Layerの実装記録

確認日: 2026-08-15
対象ブランチ: `feature/dya-studio-full-support`
状態: 自動検証完了、実機確認待ち

## 目的

DYA Studio内蔵の「接続」画面から、BLEプロファイルと接続先ごとの既定レイヤーを管理できるようにする。OS検出を利用すると、同じ接続先でもWindows、macOS、Linux、iOS、Androidごとに異なるレイヤーを適用できる。

このフェーズではローカルWeb UIや独自モジュールを作成しない。DYA Studioが対応しているcormoran氏の公開upstreamモジュールを、ソース変更せずに利用する。

## 採用した依存

| Module | 採用コミット | 用途 |
| --- | --- | --- |
| `zmk-module-ble-management` | [`57738cc4fc6ba80e82a7ac57741a0339cb186cd4`](https://github.com/cormoran/zmk-module-ble-management/commit/57738cc4fc6ba80e82a7ac57741a0339cb186cd4) | BLEプロファイル、名称、接続切替、解除、USB／BLE優先順位 |
| `zmk-feature-os-detection` | [`3052679f645b8fc1997275c2eaa6b86bdd55ca01`](https://github.com/cormoran/zmk-feature-os-detection/commit/3052679f645b8fc1997275c2eaa6b86bdd55ca01) | USB／BLE接続先のOS推定と手動override |
| `zmk-feature-default-layer` | [`b25cb5b324da2d9bbc84e1877c775f5b2b7c6845`](https://github.com/cormoran/zmk-feature-default-layer/commit/b25cb5b324da2d9bbc84e1877c775f5b2b7c6845) | USB、BLEプロファイル、OSごとの既定レイヤー |

可変ブランチではなく、調査時点で各upstreamのCIが成功しているコミットSHAへ固定した。Default Layerは、現行DYA2が使用する`codex/custom-rpc-rewrite`系列のコミットである。

## 構成

3機能とStudio RPCは、ホスト接続を管理する右Centralだけで有効にした。左Peripheralには追加していない。

| 項目 | 設定値 |
| --- | --- |
| BLEプロファイル | 従来どおり5件 |
| Default Layer対象 | Layer 0～10 |
| USB OS検出 | 有効 |
| BLE OS検出 | 有効 |
| BLE GATT Client Probe | 無効（upstream既定値） |
| OS Detection単体のLayer Auto Switch | 無効 |
| Default LayerのOS連携 | 有効 |

OS Detection自身にも自動レイヤー切替機能があるが、Default Layerと同時に使うと両方がレイヤーを操作する。upstreamの案内に従い、OS Detection単体の切替は無効のままにして、Default Layerだけが適用を担当する。

起動直後はUSBと全BLEプロファイルの割り当てが`未設定`である。この場合は従来どおりLayer 0が使用されるため、ファームウェアを書き込んだだけではキーマップ動作は変わらない。

## レイヤー選択の運用

DYA Studioには、既存のLayer 0～6と予約済みのLayer 7～10がすべて表示される。これはupstreamの標準仕様であり、独自の許可リストは追加していない。

Layer 1～6はMouse、Lower、Mid、Raise、Scroll、Adjust用で、単独の基本レイヤーとしては透明キーが多い。接続先の既定レイヤーには、次のいずれかを使用する。

- 従来動作を維持する場合は`未設定`またはLayer 0
- OS別配列を作る場合は、DYA Studioで編集したLayer 7～10

設定は変更時にFlashへ即時保存される。設定画面のSave All操作は不要である。

## Studio Lockの扱い

3つのupstreamモジュールは、接続画面用RPCを`Unsecured`として登録している。そのため、本番ファームウェアでも接続画面の表示と変更にStudio Unlockは要求されない。今回は公開upstreamの仕様を変えない方針に従い、独自のLock保護は追加していない。

接続設定を変更するときは、信頼できるPCからUSB接続したDYA Studioだけを使用する。特にプロファイル解除とUSB／BLE優先順位の変更は、対象を確認してから実行する。

## OS検出の制約

OS検出はUSB列挙やBLE GATTアクセスの特徴を利用するヒューリスティックであり、必ず正解する機能ではない。特に接続直後は判定が変化する可能性がある。

誤判定した接続先では、DYA Studioのプロファイルごとのoverrideを使ってOSを固定する。USB経由ではmacOSとiOSを区別できず、AndroidのUSB接続はLinuxとして判定される場合がある。

## 自動検証

`./scripts/zmk-build.sh dya`で6成果物をクリーンビルドし、すべて成功した。

| 成果物 | text | data | BSS | Flash | RAM | UF2 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 標準 左Peripheral | 196,260 B | 23,474 B | 70,887 B | 30.14% | 28.58% | 439,808 B |
| 標準 右Central本番版 | 299,888 B | 67,807 B | 136,996 B | 50.43% | 55.69% | 735,744 B |
| 標準 右Central開発版 | 299,796 B | 67,760 B | 136,995 B | 50.41% | 55.67% | 735,232 B |
| `double_ball` 左Peripheral | 202,868 B | 24,030 B | 71,051 B | 31.12% | 28.71% | 454,144 B |
| `double_ball` 右Central | 300,884 B | 68,653 B | 137,736 B | 50.69% | 56.01% | 739,328 B |
| Settings Reset | 50,808 B | 3,837 B | 12,179 B | 7.50% | 5.02% | 109,568 B |

フェーズ6比で標準右Centralはtextが5,116 B、dataが5,560 B、BSSが3,022 B増加した。Flashは1.46ポイント、RAMは1.29ポイント増加したが、いずれも十分な空きがある。

標準左Peripheral、`double_ball`左Peripheral、Settings Resetはフェーズ6とSHA-256が同一である。右Centralだけに接続管理機能が追加されたことを、`scripts/check-connection-features.sh`で次のとおり検査した。

- 本番版、開発版、`double_ball`版に3つのStudio RPCが入る
- 左Peripheralには3機能とRPC識別子が入らない
- BLEプロファイル数が従来どおり5件である
- Default Layerの対象が0～10である
- 競合するOS Detection側のLayer Auto Switchが無効である
- Idle 30秒、Deep Sleep 150分が変わっていない
- 既存のRuntime Input Processor検査も引き続き成功する

## 実機確認手順

標準構成では左Peripheralのバイナリに変更がないため、右Centralだけを書き換える。

1. 念のため、DYA Studioのキーマップをエクスポートする。
2. 右へ`torabo_tsuki_lp_right_central.uf2`を書き込む。
3. キー、トラックボール、左右間接続が従来どおり動作することを確認する。
4. USB接続でDYA Studioを開き、「接続」画面を表示する。
5. 画面上部のエラーが消え、USBとBLEプロファイル5件が表示されることを確認する。
6. 最初はUSBと使用中BLEプロファイルを`未設定`のままにし、現在のOS表示だけを確認する。
7. テスト用BLEプロファイルの既定レイヤーをLayer 0に設定し、接続を切り替えて入力できることを確認する。
8. DYA StudioでLayer 7～10のいずれかにテスト用配列を作り、テスト用BLEプロファイルへ設定する。
9. BLE接続へ切り替え、指定したレイヤーになることを確認する。
10. OS別設定を行い、接続先を`OS検出に従う`へ変更して結果を確認する。
11. OS判定が違う場合はプロファイルのoverrideでOSを固定し、正しいレイヤーになることを確認する。
12. 再起動後もプロファイル名、override、既定レイヤーが保存されていることを確認する。
13. USB／BLE優先順位はDYA Studioとの接続が切れる場合があるため、最後に確認する。
14. テスト用プロファイルだけを解除し、他のペアリングが残ることを確認する。

既存のLayer 1～6を接続先へ指定しない。誤って入力しづらいレイヤーを指定した場合はUSB接続でDYA Studioを開き、対象を`未設定`またはLayer 0へ戻す。復旧できない場合だけSettings Resetファームウェアを使用する。

## 次の作業

上記の実機確認が完了した後、同じフェーズの残項目である`zmk-module-settings-rpc`を別コミットで追加する。接続管理の問題と本体設定の問題を切り分けるため、今回は同時に有効化しない。
