# 左ミニトラックパッドの運用メモ

左に公式ミニトラックパッド、右にトラックボールを搭載する構成です。左はPeripheral、PCと接続する右はCentralです。

## ファームウェアの構成

| 書き込み先 | UF2 |
| --- | --- |
| 左 | `torabo_tsuki_lp_mini_trackpad_left_peripheral.uf2` |
| 右 | `torabo_tsuki_lp_mini_trackpad_right_central.uf2` |

この左右を組にして使用します。通常版やdouble-ball版には、今回の左スクロール用設定は含まれません。

左は既存の`input-trackpad-mini`と`input-split`でセンサー入力を送信します。右は`input-split-trackpad-mini`で受信し、専用Runtime Input Processorの`lpad`へ渡します。センサーが既に`INPUT_REL_HWHEEL`（横）と`INPUT_REL_WHEEL`（縦）を生成するため、XY移動からの変換は行いません。タップで発生するボタン入力は変更せずに通します。

| Studioの識別名 | 対象 | 初期値 |
| --- | --- | --- |
| `mouse` | 右トラックボールのカーソル移動 | 従来の設定 |
| `scroll` | 右トラックボールのScrollレイヤーでの入力 | 従来の設定 |
| `lpad` | 左ミニトラックパッドのスクロール | 感度`1/60`、回転0度、追加の反転なし、全レイヤーで有効 |

`lpad`の自動MouseレイヤーとXY→Scroll変換は無効です。感度`1/60`は通常スクロール向けの仮値であり、実機で調整してください。`track-remainders`で小さい移動の端数を次の入力へ持ち越します。

設定は右Centralに保存します。`lscroll`とは別の保存名を使うため、double-ball版で保存した設定を流用しません。右Centralの物理レイアウトには`Left Mini Trackpad`を追加し、`lpad`に関連付けています。位置・大きさはM配列の左電池カバー付近の代表値です。

## ビルドと生成物の確認

リポジトリのルートで実行してください。

```sh
# Dockerで今回使用する左右のファームウェアをビルドします。
./scripts/zmk-build.sh dya torabo_tsuki_lp_mini_trackpad_left_peripheral torabo_tsuki_lp_mini_trackpad_right_central

# 実際の生成物に、正しい入力経路とStudio設定が含まれるか確認します。
bash scripts/check-mini-trackpad.sh
```

UF2は`.build/local/dya/<成果物名>/<成果物名>.uf2`に生成されます。検査スクリプトは左右のSplit番号、左ドライバー、Wheel入力の処理先、Studioの3項目、物理表示とのリンク、Studio Lock、通常スクロール設定を確認します。

## 実装時の検証結果

2026-09-20にZephyr 4.1のDocker環境で専用の左右UF2をビルドし、`check-mini-trackpad.sh`の検査に成功しました。既存の通常版・開発版・double-ball版・Settings Resetの6構成も再ビルドし、計8構成すべて成功しました。

既存の`check-runtime-input-processors.sh`、`check-settings-rpc.sh`、`check-connection-features.sh`も再ビルドした生成物で成功しています。新しい検査スクリプトのシェル構文と差分の空白エラーも確認済みです。

| 専用構成 | Flash使用量 | RAM使用量 |
| --- | --- | --- |
| 左Peripheral | 228,592 B / 712 KiB（31.35%） | 75,376 B / 256 KiB（28.75%） |
| 右Central | 371,216 B / 712 KiB（50.92%） | 146,580 B / 256 KiB（55.92%） |

既存設定由来のPeripheralでは有効にならないKconfig設定の警告や、上流コードのコンパイル警告は残っています。ビルド失敗はありません。実機のスクロール量、Studio画面での操作、設定の再起動後の復元、スリープ復帰は未検証です。以下の手順で確認してください。

## 実機での確認手順

1. 左右それぞれをブートローダーモードにし、対応するUF2を書き込んで再起動します。設定初期化は通常不要です。
2. 右をUSBでPCへ接続し、左右のキー入力と右トラックボールが動くことを確認します。
3. 左を上下に操作して縦スクロールを確認します。横スクロールはセンサー座標のY方向0〜15%の帯で開始する仕様です。取り付け方向によって物理的な帯の位置が変わるため、上下の端を確認してください。
4. 指を離した後の慣性、再タッチでの停止、タップ、右トラックボールとの同時使用を確認します。Base、macOS、Mouse、Scrollレイヤーでも左スクロールを確認します。
5. ChromeまたはEdgeで[DYA Studio安定版](https://studio.dya.cormoran.works)を開き、右Centralへ接続します。`Mid + Raise`でAdjustレイヤーへ入り、左上のStudio Unlockキーを押します。
6. Runtime Input Processor画面に`mouse`・`scroll`・`lpad`が表示され、物理表示の`Left Mini Trackpad`から`lpad`へ移動できることを確認します。
7. `lpad`の倍率を`1/60`から`2/60`に変更し、左だけが速くなることを確認します。X反転は横、Y反転は縦に対応します。方向が逆なら該当する反転を変更します。回転は0度、XY入れ替え・XY→Scroll・自動Mouseは無効のまま使用してください。
8. 保存するモードで適用し、保存完了後、少なくとも10秒待って左右を再起動します。再接続・Unlock後に感度と方向が復元されることを確認します。
9. USBを外してPCとのBLE接続でも試し、Idle後・Deep Sleepからのキーによる復帰後に左右入力が戻ることを確認します。

Studio Lock中はRuntime Input Processorの一覧・変更が保護されます。感度調整の検証はUnlock後に行ってください。

既存の汎用Studio画面には、今回の用途に適さない設定も表示されます。採用中のProcessorの回転処理は両軸の入力を待つため、片軸だけを送るミニトラックパッドでは入力が出なくなる場合があります。また、XY入れ替えは出力コードをカーソルのXYへ変更します。今回の操作方向の調整にはX反転・Y反転を使用してください。

## 今回の対応範囲と高分解能化

今回は通常スクロールを使用し、右側の`CONFIG_ZMK_POINTING_SMOOTH_SCROLLING=n`を明示しています。左の慣性は既存ドライバーを利用します。慣性の減衰率・横スクロール領域・タップ判定の調整値はビルド時設定です。これらをStudioから変更するRPCは今回追加していません。

高分解能化には、採用中のZMKの`apply_resolution_scaling()`の検証が必要です。`scaled`を計算した後、イベントに補正前の`val`を代入しています。例えば倍率の除数が16、入力が16、端数が0の場合、計算上は1ですが、イベントには16が残ります。このため、有効化だけでホストの要求どおりの倍率になるとは判断できません。

次の段階では、ホストによるHID Resolution Multiplierの指定、補正処理、USB／BLE双方のレポートを確認し、必要な上流修正を固定したうえで有効化します。右トラックボールのスクロールにも同じ設定が適用されるため、左右両方で速度と微小移動を検証します。

- [公式の取り付け・ファームウェア案内](https://github.com/sekigon-gonnoc/torabo-tsuki-lp/blob/master/mini-trackpad-option.md)
- [採用中のIQS7211Eドライバー](https://github.com/sekigon-gonnoc/zmk-driver-iqs7211e/tree/436d3c42172abf812ec104521f29384fc02fc50e)
- [採用中のZMK倍率処理](https://github.com/cormoran/zmk/blob/e5c9b6915b56801193e359dd9bad4a167ce0d1b8/app/src/pointing/input_listener.c)
