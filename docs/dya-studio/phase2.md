# フェーズ2 Manifest・CI再構成の検証記録

確認日: 2026-08-12
対象ブランチ: `feature/dya-studio-full-support`

## 目的

DYA2参照実装に合わせてManifestとビルド方法を整理し、ローカルとGitHub Actionsで同じ `west zmk-build` を使用できるようにする。

このフェーズではキーマップやデバイス設定を変更しない。左Peripheral、右Central、Settings Resetの3成果物を、フェーズ1の安定版と同じ機能設定で生成する。

## 実装内容

- 共通依存を `config/west-dependency.yml` へ分離
- 単独利用向けに `config/west-standalone.yml` を追加
- 既存West workspaceへの組み込み向けに `config/west-workspace.yml` を追加
- DYA2参照実装と同じ `zmk-west-commands` をSHA固定で追加
- `build.yaml` を `artifact` と `snippets` を使う形式へ移行
- 現在使用する3構成だけを必須ビルドとして定義
- 将来構成のコメントアウト定義を削除し、実装時に別build定義へ追加する方針へ変更
- GitHub Actionsを再利用workflow方式から、`west zmk-build` の直接実行方式へ変更
- West依存物のGitHub Actionsキャッシュを追加
- ローカルビルドも `west zmk-build` を使用するよう統一

成果物名は、通常運用する本番用では役割をそのまま表す。フェーズ3以降で追加する開発用成果物には `_develop` を付け、本番用と区別する。

## ローカル検証結果

standalone Manifestから新規West workspaceを初期化し、次の3構成が一括ビルドに成功した。

| 成果物 | 結果 |
| --- | --- |
| `torabo_tsuki_lp_left_peripheral.uf2` | 成功 |
| `torabo_tsuki_lp_right_central.uf2` | 成功 |
| `settings_reset-bmp_boost-zmk.uf2` | 成功 |

静的検査もすべて成功した。

- Shellスクリプト構文検査
- Manifest、build、Compose、GitHub ActionsのYAML解析
- `docker compose config --quiet`
- `git diff --check`

## フェーズ1安定版との比較

比較対象は、Manifest再構成直前に同じソースから生成したフェーズ1安定版である。

| 項目 | 左Peripheral | 右Central | Settings Reset |
| --- | --- | --- | --- |
| DeviceTree | 完全一致 | 完全一致 | 完全一致 |
| 機能Kconfig | 完全一致 | 完全一致 | 完全一致 |
| text | 178,172 Bで一致 | 246,396 Bで一致 | UF2完全一致 |
| BSS | 38,376 Bで一致 | 71,387 Bで一致 | UF2完全一致 |
| data | +352 B | +416 B | UF2完全一致 |

Kconfigの全設定行を比較すると、差は自動生成された `CONFIG_ZEPHYR_ZMK_WEST_COMMANDS_MODULE=y` だけだった。`zmk-west-commands` のZephyr module定義には、これはビルドツールであり、CMake/Kconfigや実行時コードを持たない不活性なモジュールであることが明記されている。

左右UF2のハッシュとdataサイズは、補助モジュールの登録に伴う生成情報・配置の変化により一致しない。一方、命令領域のサイズ、BSS、DeviceTree、既存の全機能Kconfigは一致しているため、フェーズ1で確認したキー入力・ポインター・分割接続・省電力の動作仕様は変更していないと判断する。

## CI確認

コミット・push後にGitHub Actionsで次を確認する。

- クリーン環境からWest workspaceを初期化できる
- 3構成がすべてビルド成功する
- `firmware` artifactに3つのUF2が含まれる
- UF2名から左Peripheral、右Central、Settings Resetを識別できる

## ユーザー確認

フェーズ2はビルド基盤だけの変更で、機能設定は自動比較済みのため実機への再書き込みは不要。

GitHub Actions成功後、成果物一覧に次の3ファイルがあることだけ確認できればよい。

```text
torabo_tsuki_lp_left_peripheral.uf2
torabo_tsuki_lp_right_central.uf2
settings_reset-bmp_boost-zmk.uf2
```
