# 接続先別Default Layerの運用メモ

確認日: 2026-08-15
対象ブランチ: `feature/dya-studio-full-support`
状態: 実装・自動検証完了、実機確認待ち

## 目的

DYA Studioの接続先別Default Layerで、通常配列とmacOS配列を安全に切り替える。独自の切替処理は追加せず、`zmk-feature-default-layer`とZMK標準のレイヤー機能だけを使用する。

## レイヤー構成

ZMKは番号の大きいレイヤーを優先する。このため、接続先ごとの基本レイヤーを下位、MouseやLowerなどの一時的な機能レイヤーを上位へ配置する。

| Layer | 名前 | 用途 |
| ---: | --- | --- |
| 0 | Base | 通常の基本配列 |
| 1 | macOS | macOS用の基本配列 |
| 2 | Mouse | Auto Mouseとマウスボタン |
| 3 | Lower | 記号と数字 |
| 4 | Mid | 数字とカーソル |
| 5 | Raise | Functionキーとテンキー |
| 6 | Scroll | トラックボールのスクロール |
| 7 | Adjust | BluetoothとStudio Unlock |
| 8～10 | 予約 | DYA Studioで追加編集するための空き領域 |

Default Layerで選択できる範囲はLayer 0～1に限定する。機能レイヤーを誤って接続先の基本レイヤーへ指定することを防ぐためである。

## macOSレイヤー

macOSレイヤーは、通常キーをすべて透明にしてBaseレイヤーを引き継ぐ。修飾キーだけを次のように上書きする。

| Baseでのキー | macOSでのキー |
| --- | --- |
| Control | Control（Baseを継承） |
| Windows | Option（Left Alt） |
| Alt | Command（Left GUI） |
| Windows + Tab | Command + Tab（Baseを継承） |

この構成では通常キーをBaseとmacOSへ重複して定義しないため、今後Baseを編集したときもmacOSへ自動的に反映される。

## Input Stream表示の調査結果

[`zmk-feature-input-stream`](https://github.com/cormoran/zmk-feature-input-stream/blob/aeb015908a42a7615ccdccc7feb3a10d23132a71/src/studio/input_stream_handler.c#L183-L197)は、レイヤー状態が変化したときに「現在有効な最上位レイヤー」をDYA Studioへ通知する。接続先のDefault LayerをLayer 7へ置くと、LowerなどのLayer 2～6を有効にしてもLayer 7が最上位のままなので、画面表示が切り替わらない。

macOSをLayer 1へ移動し、機能レイヤーをLayer 2～7へ置くことで、キー操作中の最上位レイヤーを正しく通知できる。

[DYA Studio側の通知処理](https://github.com/cormoran/dya-studio/blob/33d08bdfaf85995d0bacc79ee33d16a8df4217ba/src/hooks/useInputStream.ts#L184-L197)には次の制約が残る。

- キーマップ画面から離れるとInput Streamが停止する
- Input Stream開始時には、現在のレイヤー状態を最初に取得しない
- Input StreamにはBLEプロファイル番号やプロファイル名の通知がない

そのため、[接続画面でプロファイルを変更しながらInput Streamを同時に表示することはできない](https://github.com/cormoran/dya-studio/blob/33d08bdfaf85995d0bacc79ee33d16a8df4217ba/src/pages/KeymapPage.tsx#L355-L377)。キーマップ画面へ戻ってStreamを開始し、その後にキー操作または接続先切替を行って確認する。これは上流の現行仕様であり、このファームウェアでは独自修正しない。

## 自動検証

`./scripts/zmk-build.sh dya`で6成果物をクリーンビルドし、すべて成功した。続けて次の検査にも成功した。

- `scripts/check-runtime-input-processors.sh`
- `scripts/check-connection-features.sh`
- 生成Devicetreeのレイヤー名と順序
- Auto MouseのLayer 2とScrollのLayer 6
- Default Layerの選択範囲0～1
- Centralだけに接続管理RPCが含まれること

| 成果物 | text | data | BSS | UF2 SHA-256 |
| --- | ---: | ---: | ---: | --- |
| 標準 左Peripheral | 196,260 B | 23,474 B | 70,887 B | `8a5b44375c9ae5f612b212fbda993d1bf0112e8bd4f0de820a10f64dfe76dedf` |
| 標準 右Central本番版 | 299,924 B | 67,807 B | 136,996 B | `7a874fe6840d3c268f250179d496317424c3af312c6bce7f800d88347198055b` |
| 標準 右Central開発版 | 299,828 B | 67,760 B | 136,995 B | `98cae1f2b6b2ef2931d615030ffec68a865b47bbf6d01fb6972eae751d6bf5fd` |
| `double_ball` 左Peripheral | 202,868 B | 24,030 B | 71,051 B | `868dea8f64a6e8f1b83159ad9d24d4e0b957e96836611e5848c0bc5535b217c1` |
| `double_ball` 右Central | 300,920 B | 68,653 B | 137,736 B | `c2101286b7628f4dfb87a56e03f86f984dc8b1de2cc75c5cb681b09e12e219cf` |
| Settings Reset | 50,808 B | 3,837 B | 12,179 B | `1481398b551dd7b1032c9d86b2966ba579b77cac3b1302fad95203727221cfeb` |

標準右Centralは変更前からtextが36 B増えただけで、dataとBSSは変わっていない。FlashとRAMへの実質的な影響はない。

## 旧設定からの移行

レイヤー番号が変わるため、保存済み設定を残したまま書き込むと旧番号が別のレイヤーを指す場合がある。書き込み前後に次の手順を実施する。

### 書き込み前

1. DYA Studioでキーマップをエクスポートする。
2. 「接続」で、すべての接続先とOS別Default Layerを`未設定`またはLayer 0へ戻す。
3. 必要ならRuntime Input Processorの現在値を記録する。

### 書き込み後

1. 標準構成では左Peripheralと右Centralの両方へ、同じビルドのUF2を組にして書き込む。
2. DYA Studioのキーマップ画面でResetを実行し、ファームウェアの既定キーマップを読み込む。
3. Runtime Input ProcessorでReset Allを実行し、Auto MouseをLayer 2、ScrollをLayer 6へ更新する。
4. Windowsなど通常配列を使う接続先にはLayer 0を指定する。
5. macOSを使う接続先にはLayer 1を指定する。
6. Runtime Input ProcessorでSave Allを実行し、再起動後も設定が維持されることを確認する。接続先別Default Layerは変更時に自動保存される。

DYA Studioで独自に作成していた削除済みレイヤーは、ファームウェアから内容を推測できない。必要な場合は、手順1で保存したエクスポートを参照しながら再作成する。

## 実機確認項目

1. Layer 0で従来のBase配列が入力できる。
2. Layer 1でControl、Option、Command、Command + Tabが正しい位置から入力できる。
3. Windows用接続先ではLayer 0、macOS用接続先ではLayer 1になる。
4. Lower、Mid、Raise、Scroll、AdjustがそれぞれLayer 3～7として動作する。
5. トラックボール操作でMouseレイヤー2が有効になり、クリックとスクロールが動作する。
6. キーマップ画面のInput Streamで、Base／macOSと各機能レイヤーの切替が表示される。
7. 再起動後もDefault LayerとRuntime Input Processorの保存値が維持される。
