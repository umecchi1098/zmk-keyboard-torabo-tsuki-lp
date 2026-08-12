# フェーズ1 DYA向け基盤更新の検証記録

記録日: 2026-08-12
対象ブランチ: `feature/dya-studio-full-support`

## 調査結果

次の公式情報とDYA2参照実装を確認した。

- [DYA2公式ファームウェア](https://github.com/cormoran/zmk-keyboard-dya2)
- [ZMK Zephyr 4.1移行ガイド](https://zmk.dev/blog/2025/12/09/zephyr-4-1)
- [ZMK Studio公式ガイド](https://zmk.dev/docs/features/studio)

DYA2参照実装の確認コミットは `eca79a3a9adfb0b9015508db1fa4572f6680152f`。参照実装が使用するDYA向けZMKとnRF半二重UART対応Zephyrを、2026-08-12時点の次のコミットへ固定した。

| Project | 参照ブランチ | 採用コミット |
|---|---|---|
| `cormoran/zmk` | `main+dya` | `e5c9b6915b56801193e359dd9bad4a167ce0d1b8` |
| `cormoran/zephyr` | `v4.1.0+zmk-fixes+nrf-half-duplex-uart` | `7c6b4cc486ecb41a68d9c2b1def2bb3178fbb826` |

フェーズ1では新しいDYA用モジュールやKconfigを追加していない。既存のStudio RPC snippetと既存機能だけを、更新後の基盤でビルドした。

GitHub Actionsは構成を再編せず、再利用Workflowの参照先だけを同じDYA向けZMKコミットへ更新した。Manifest・キャッシュ・ビルドマトリクス自体の再構成はフェーズ2で行う。

## 外部モジュールの互換性

| Module | 採用コミット | 結果 |
|---|---|---|
| `zmk-component-bmp-boost` | `2f5567523b6f0bc39575d48ed746ed9d635edf8b` | Zephyr 4.1のHWMv2対応版へ更新 |
| `zmk-feature-status-led` | `572d0e16ecdd6b6d57e96461643cc55e7b9164d3` | 左右成果物でコンパイル成功 |
| `zmk-driver-paw3222` | `0e1835c57f88d215ce401b6d0901f361629621fc` | 既定の右Centralでコンパイル成功、node生成を確認 |
| `zmk-driver-iqs7211e` | `436d3c42172abf812ec104521f29384fc02fc50e` | 検証用`input-trackpad-mini`構成でコンパイル成功、node生成を確認 |
| `zmk-feature-cdc-acm-bootloader-trigger` | `3fc210f840433bb9204a510f3a2c78b4fa11482f` | 左右成果物でコンパイル成功 |
| `zmk-feature-non-lipo-battery-management` | `bf024bb7872917f718a960d804136db5f9b88a31` | 左右成果物でコンパイル成功 |

既定配布構成はPAW3222を使用するため、IQS7211Eは3つの配布成果物には含まれない。互換性確認だけを目的として右Centralを`input-trackpad-mini` snippetで別途ビルドし、`.build/local/dya/compatibility_iqs7211e/`へ結果を保存した。この検証用成果物は`build.yaml`へ追加していない。

## 前方移植

Zephyr 4.1では入力コールバック登録APIにユーザーデータ引数が追加された。`src/board.c`のトラックボール入力コールバックを新しい関数シグネチャへ合わせ、未使用引数を明示的に処理した。動作は従来どおり、ポインター入力を検出したときに省電力用のアイドルタイマーをリセットする。

## ローカルDockerビルド

次のコマンドで、`zmkfirmware/zmk-dev-arm:4.1-branch`を使用して3成果物をクリーンビルドした。

```bash
./scripts/zmk-build.sh dya
```

すべて成功し、UF2、ビルドログ、Kconfig、生成Devicetreeを`.build/local/dya/`へ保存した。

| 成果物 | UF2 | Flash | RAM | SHA-256 |
|---|---:|---:|---:|---|
| 左Peripheral | 397,824 B | 198,848 B | 41,992 B | `fe55f0edd2c979612d3587e142f190abcf72080dbe69c1c570c6790fb28eeef4` |
| 右Central | 570,368 B | 284,996 B | 77,158 B | `ca19ba119955a791a96386f40bc5e4678c826008f55559447cf78be4d35af61d` |
| Settings Reset | 109,568 B | 54,652 B | 13,152 B | `1481398b551dd7b1032c9d86b2966ba579b77cac3b1302fad95203727221cfeb` |

## ベースラインとのサイズ比較

| 成果物 | Flash差分 | RAM差分 | Zephyr 4.1での使用率 |
|---|---:|---:|---|
| 左Peripheral | +18,944 B（+10.5%） | +3,860 B（+10.1%） | Flash 27.27%、RAM 16.02% |
| 右Central | +21,476 B（+8.2%） | +4,556 B（+6.3%） | Flash 39.09%、RAM 29.43% |
| Settings Reset | +6,688 B（+13.9%） | +1,296 B（+10.9%） | Flash 7.50%、RAM 5.02% |

全成果物がFlash 40%未満、RAM 30%未満であり、後続フェーズの機能追加に必要な余裕がある。

## 生成物の静的検証

右Centralの生成Devicetreeで、次を確認した。

- PAW3222 node
- `auto_mouse_layer`
- X・Y反転を含む既存input processor chain
- Scrollレイヤー5、X反転、倍率`1/64`のprocessor chain
- M Physical Layoutの選択
- Base、Mouse、Lower、Mid、Raise、Scroll、Adjustの既存7レイヤー

IQS7211E検証用Devicetreeでは、`azoteq,iqs7211e` nodeと同じ既存input processor chainを確認した。キーマップとPhysical Layoutのソースは変更していない。

## 警告の整理

ビルドを失敗させる新規警告はない。次は上流または既存構成由来として記録し、フェーズ1では動作変更を避けて残す。

- 左PeripheralへCentral専用設定が読み込まれ、依存条件により無効化されるKconfig警告
- `KSCAN`と`BT_CTLR`の非推奨警告
- DYA向けZMKの`input_processor_temp_layer.c`にある未使用変数警告
- Settings Resetの空キーマップに起因する配列警告
- Settings Resetでは非LiPo電池管理nodeがないため設定が無効化される警告

`src/board.c`の入力コールバックAPI移行に伴って一度発生した型不一致警告は解消済み。

## 未完了ゲート

- GitHub Actionsのクリーン環境で3成果物をビルドする
- CI成功後、左右実機へUF2を書き込んで回帰チェックを行う
