
[torabo-tsuki LP](https://github.com/sekigon-gonnoc/torabo-tsuki-lp)用のZMKファームウェア

* _centralがついているuf2をトラックボールがついている方に、_peripheralを反対側に書き込んでください
* キーマップはkeymap-editorおよびzmk-studioで編集できます

## DYA Studio

[DYA Studio安定版](https://studio.dya.cormoran.works)をChromeまたはEdgeで開き、右CentralをUSB接続するとキーマップを編集できます。

通常運用には `torabo_tsuki_lp_right_central.uf2` を使用してください。本番版は誤操作防止のStudio Lockが有効です。`Mid + Raise` でAdjustレイヤーへ入り、左上のキーを押すと編集を解除できます。

Runtime Input Processor画面では、トラックボールの感度、回転、軸反転、自動Mouse、Scroll設定を変更・保存できます。通常版には`mouse`と`scroll`が表示されます。詳しい既定値と確認手順は[フェーズ6の検証記録](docs/dya-studio/phase6.md)を参照してください。

「接続」画面では、BLEプロファイル、USB／BLE優先順位、OS検出、接続先ごとの既定レイヤーを管理できます。接続先にはLayer 0のBaseまたはLayer 1のmacOSを指定でき、初期値の`未設定`では従来どおりLayer 0を使用します。レイヤー番号の移行手順とInput Streamの制約は[Default Layer運用メモ](docs/dya-studio/default-layer-layout.md)を参照してください。

`torabo_tsuki_lp_right_central_develop.uf2` はStudio Lockを無効にした開発・切り分け専用版です。通常運用には使用しないでください。

左右両方にポインターを搭載する場合だけ、`torabo_tsuki_lp_double_ball_left_peripheral.uf2`と`torabo_tsuki_lp_double_ball_right_central.uf2`を組にして使用してください。標準版との混在は避けてください。

## 省電力設定について

Zephyr 4.1環境では、旧customファーム由来の段階的な左右間BLE省電力処理を既定で無効にしています。無操作後に左Peripheralが操作不能になる問題が実機で発生したためで、修正版では接続が維持されることを確認済みです。

ZMK標準のIdle（30秒）とDeep Sleep（150分）は引き続き有効です。安定性を優先し、独自BLE省電力処理は再有効化せずに運用します。原因、影響、再検討条件の詳細は[フェーズ1の検証記録](docs/dya-studio/phase1.md#実機回帰と修正方針)を参照してください。

ローカルビルドはWSL2上のDockerを使用します。セットアップと実行方法は [DOCKER_BUILD.md](DOCKER_BUILD.md) を参照してください。
