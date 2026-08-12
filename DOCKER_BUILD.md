# WSL + Docker ローカルビルド

このリポジトリのローカルビルドは、WSL2から公式ZMK開発コンテナを実行する。ホストへZMK、Zephyr、West、Zephyr SDKを直接インストールする必要はない。

ローカルビルドは実装中の高速なフィードバック用であり、最終的な合否判定と配布用成果物の生成はGitHub Actionsを正とする。

## 前提

- WSL2
- WSLから利用できるDocker EngineまたはDocker DesktopのWSL Integration
- Docker Compose v2
- Git

確認:

```bash
docker version
docker compose version
```

リポジトリは、性能とLinux互換性のためWSLのLinuxファイルシステムへクローンすることを推奨する。

```bash
mkdir -p ~/src
cd ~/src
git clone https://github.com/umecchi1098/zmk-keyboard-torabo-tsuki-lp.git
cd zmk-keyboard-torabo-tsuki-lp
```

## ビルド

すべての有効な成果物をビルドする。

```bash
./scripts/zmk-build.sh
```

`config/west-dependency.yml` の内容から、通常は次の環境が自動選択される。

- 現行ZMK v0.3: `zmkfirmware/zmk-dev-arm:3.5`
- DYA／Zephyr 4.1: `zmkfirmware/zmk-dev-arm:4.1-branch`

現行構成では `dya` が選択される。依存関係は `config/west-standalone.yml` から初期化され、`dependencies/` 配下へまとめられる。

`baseline` は移行前ファームウェアとの比較専用として残している。通常の開発・配布では `dya` を使用する。

環境を明示する場合:

```bash
./scripts/zmk-build.sh baseline
./scripts/zmk-build.sh dya
```

単一成果物だけをビルドする場合:

```bash
./scripts/zmk-build.sh dya torabo_tsuki_lp_right_central
```

成果物と検証資料は次に出力される。

```text
.build/local/<environment>/<artifact-name>/
├── <artifact-name>.uf2 または .bin
├── build.log
├── firmware-size.txt
├── kconfig
└── zephyr.dts
```

`.build/` はGit管理対象外である。

## キャッシュ

現行環境とDYA環境は、異なるDocker VolumeへWestワークスペースを保存する。初回は依存リポジトリとイメージを取得するため時間がかかるが、2回目以降はキャッシュが利用される。

```text
zmk-west-baseline  # ZMK v0.3 / Zephyr 3.5
zmk-west-dya-v2    # DYA / Zephyr 4.1（DYA2形式のManifest）
```

`config/` は実行ごとにコンテナ内ワークスペースへ同期され、`west update --narrow` が実行される。リポジトリ本体はコンテナへ読み取り専用でマウントされる。

ビルドはDYA2参照実装と同じ `west zmk-build` を使用する。依存関係のSHAは `config/west-dependency.yml` に固定している。

## CI/CDとの役割分担

- ローカルDocker: 編集中のビルド、ログ確認、Kconfig／Devicetree確認、サイズ比較
- Pull Request CI: クリーン環境での全成果物ビルド、マージ可否判定
- 既定ブランチCI: 配布候補ファームウェアの生成
- 実機確認: CI成功後の必要最小限の確認

ローカル成功だけでフェーズの最終ビルド合格とはしない。該当フェーズのPull Request CIが成功して初めて、最終的な自動検証成功として扱う。

## トラブルシューティング

DockerをWSLから利用できない場合は、Docker DesktopのWSL IntegrationまたはWSL内Docker Engineを確認する。WindowsネイティブへZMKツールチェーンを追加して回避する必要はない。

利用可能な成果物名は `build.yaml` の `artifact` で確認する。各項目には、対象を誤認しない明示的な名前を必ず設定する。
