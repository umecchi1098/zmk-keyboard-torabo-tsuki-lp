# DYA Studio Settings RPC運用メモ

確認日: 2026-08-15
対象ブランチ: `feature/dya-studio-full-support`
状態: 実装・自動検証完了、実機確認待ち

## 目的

DYA Studioの「設定」画面から、右Centralと左PeripheralのIdleおよびDeep Sleep時間を確認・変更できるようにする。独自の省電力処理は追加せず、ZMK標準のActivity機能と公開upstreamの`zmk-module-settings-rpc`だけを使用する。

## 採用した依存

| Module | 採用コミット | 用途 |
| --- | --- | --- |
| `zmk-module-settings-rpc` | [`78f86df9e6c5edaf57bef3ccbd7f360cfdf49291`](https://github.com/cormoran/zmk-module-settings-rpc/commit/78f86df9e6c5edaf57bef3ccbd7f360cfdf49291) | IdleとDeep Sleepの表示・変更・左右同期 |

可変ブランチではなく、調査時点のupstreamコミットSHAへ固定した。ソースコードへの独自変更は行っていない。

## 構成と初期値

| 項目 | 初期値 | DYA Studioでの変更 |
| --- | ---: | --- |
| Idle | 30秒 | 可能 |
| Deep Sleep | 150分 | 可能 |
| Flashへの保存待ち時間 | 10秒 | 変更不可 |

Settings RPC本体と左右同期は両側で有効にし、DYA Studio用RPCはUSB接続を担当する右Centralだけで有効にした。DYA Studioで右側の値を変更すると、Split Relayを通して左側にも同じ値が設定され、それぞれのFlashへ保存される。

変更値は再起動後も維持される。DYA Studioの「すべての設定をリセット」またはSettings Resetファームウェアで保存値を消去すると、ファームウェアに明記したIdle 30秒、Deep Sleep 150分へ戻る。

## フェーズ1の安定化との関係

今回変更できるのはZMK標準のIdleとDeep Sleepだけである。左Peripheralが無操作後に操作不能になった原因候補の、旧customファーム由来の段階的BLE省電力処理は引き続き無効であり、Settings RPCを追加しても再有効化されない。

Idleでは通常の省電力状態へ移り、キーやポインター操作で復帰する。Deep Sleepへ入ると接続が切れ、復帰にはキー操作が必要になる。安定運用では初期値の150分を推奨する。

## 注意事項

- 変更後は左右の保存が完了するまで10秒以上待ってから電源を切る。
- `0`はupstreamではタイムアウト無効を表す。意図がない限り設定しない。
- 極端に短いDeep Sleepを設定すると、未操作時に頻繁に切断したように見える。
- Settings RPCはupstream仕様どおりStudio Lockの対象外である。信頼できるPCからUSB接続したDYA Studioだけを使用する。
- DYA StudioのCustom欄は分単位で指定できる。初期値へ手動で戻す場合、Idleは`0.5`分、Deep Sleepは`150`分を入力する。

独自の値制限やLock保護を追加するとupstreamとの差分になるため、このファームウェアでは実装しない。

## 自動検証

`./scripts/zmk-build.sh dya`で全6成果物をビルドした後、`./scripts/check-settings-rpc.sh`で次を検査する。

- 通常版と`double_ball`版の左右でSettings RPC本体が有効である
- DYA Studio用RPCと`zmk__settings`識別子は右Centralだけに含まれる
- 左右同期用Split Relayが有効である
- Idle 30秒、Deep Sleep 150分、保存待ち時間10秒を維持する
- Settings Reset成果物へSettings RPCが混入しない

検査に加えて、既存の`check-connection-features.sh`と`check-runtime-input-processors.sh`も成功した。

| 成果物 | text | data | BSS | Flash | RAM | UF2 SHA-256 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| 標準 左Peripheral | 196,788 B | 23,718 B | 70,887 B | 30.25% | 28.59% | `196d47dd5102d3d92578fcb08b83ac9f1b55ee5b7ca6bf789e95344db344d63d` |
| 標準 右Central本番版 | 301,076 B | 68,671 B | 137,068 B | 50.72% | 55.74% | `78f0d9cfabe047bb7eb83ff18a53fddffc2d2fbc84c6971e41f4b3152192115c` |
| 標準 右Central開発版 | 300,984 B | 68,624 B | 137,067 B | 50.70% | 55.73% | `252bf7a3e6216e61508ba81b357e55327e126ba877aebde696a5a241f04c1143` |
| `double_ball` 左Peripheral | 203,396 B | 24,270 B | 71,051 B | 31.23% | 28.73% | `81a245c6abf73e0347c3e8fbddfad8a997b6ffc8a90155e228ce8231295ff9cf` |
| `double_ball` 右Central | 302,072 B | 69,513 B | 137,808 B | 50.97% | 56.06% | `9cb65ec80dfc3592890deca539a89d29caa17601c43b190ae73ba85aa49cd5ff` |
| Settings Reset | 50,808 B | 3,837 B | 12,179 B | 7.50% | 5.02% | `1481398b551dd7b1032c9d86b2966ba579b77cac3b1302fad95203727221cfeb` |

直前の安定版と比べ、標準左Peripheralはtextが528 B、dataが244 B増加し、標準右Centralはtextが1,152 B、dataが864 B、BSSが72 B増加した。FlashとRAMには十分な空きがある。

## upstreamの確認事項

upstream付属テストは旧ZMKブランチ`v0.3-branch+custom-studio-protocol+activity`を対象としており、現行ZMKでは廃止された`seeeduino_xiao_ble`というボード名を使用する。このため、現行の固定ZMKコミット上ではupstream付属テストをそのまま実行できない。今回は実際に使用する6構成のクリーンビルドと生成物検査を採用した。

また、upstreamの通知失敗時の分岐に、`void`関数から値を返すコンパイラ警告が1件ある。該当分岐はRPC識別子を取得できない場合のログ処理であり、通常動作では使用されない。公開upstreamを変更しない方針のため独自修正は行わず、ビルド成功とUF2内のRPC識別子を検査して運用する。

## 実機確認手順

Settings RPC本体が左右へ追加されるため、標準構成では左Peripheralと右Centralの両方を、同じビルドのUF2へ更新する。

1. 左へ`torabo_tsuki_lp_left_peripheral.uf2`、右へ`torabo_tsuki_lp_right_central.uf2`を書き込む。
2. キー、トラックボール、左右間接続が従来どおり動作することを確認する。
3. 右をUSB接続してDYA Studioを開き、「設定」画面へ移動する。
4. CentralとPeripheralのIdleが30秒、Deep Sleepが150分と表示されることを確認する。
5. Idleを一時的に1分、Deep Sleepを一時的に180分へ変更する。
6. 10秒以上待ち、CentralとPeripheralの両方に同じ値が表示されることを確認する。
7. 左右を再起動し、変更値が維持されていることを確認する。
8. Idleを0.5分、Deep Sleepを150分へ戻し、10秒以上待つ。
9. 既存の接続先別Default Layer、キーマップ、Macro、Combo、トラックボール設定が従来どおり使えることを確認する。

Peripheralが表示されない場合は、左右間接続が成立していることを先に確認する。短いDeep Sleep値を保存して操作しづらくなった場合は、キー操作で復帰して値を戻す。復旧できない場合だけSettings Resetファームウェアを使用する。
