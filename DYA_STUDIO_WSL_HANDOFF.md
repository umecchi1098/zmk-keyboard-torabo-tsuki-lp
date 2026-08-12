# DYA Studio対応 作業引き継ぎ

最終更新: 2026-08-12
対象ブランチ: `feature/dya-studio-full-support`
起点: `dev/custom-dya` (`0b44ea6`)
完了フェーズ: フェーズ3「ZMK Studioレベル1の完成」
進行中フェーズ: フェーズ4「Custom Studio Protocolコア」
次フェーズ: フェーズ5「Macro・Combo・Input Stream」

## 環境ルール

調査、設計、ファイル編集、静的検査、Git操作は、リポジトリを安全に扱える環境で進めてよい。WSL以外であることだけを理由に作業を停止しない。

ZMK／Zephyrのローカルビルドは、WSL2からDockerを使用する。WindowsへZMKツールチェーンを直接導入しない。Dockerを利用できないセッションでは、編集と静的検査まで進め、ローカルビルド結果を未確認として残す。

ローカルDockerビルドは実装中の高速なフィードバックに使用する。最終的な自動検証、マージ判定、配布用ファームウェア生成はGitHub Actionsを正とし、ローカル成功だけでフェーズの最終合格にはしない。

## 現在の状態

- 実装用ブランチ `feature/dya-studio-full-support` は作成済み
- 起点コミットは `0b44ea6`
- フェーズ1はローカルDocker、GitHub Actions、実機回帰確認を含めて完了
- 左Peripheral切断問題への安定化対応として、旧custom由来の左右間BLE省電力処理は既定で無効
- ZMK標準のIdle（30秒）とDeep Sleep（150分）は有効なまま
- フェーズ2のManifest、ローカルビルド、CI再構成は検証を含めて完了
- 現行用とDYA用を分離した `compose.yaml` とローカルビルドスクリプトを追加済み
- 現行用Dockerイメージ: `zmkfirmware/zmk-dev-arm:3.5`
- DYA用ローカルDockerイメージ: `zmkfirmware/zmk-dev-arm:4.1-branch`
- GitHub Actions用イメージ: `zmkfirmware/zmk-build-arm:stable`
- 現行用とDYA用のWestワークスペースは別Docker Volumeを使用する
- 生成物は `.build/local/` へ出力し、Gitでは管理しない
- GitHub Actionsはpush、Pull Request、手動実行で `west zmk-build` を直接実行する
- 現行3成果物のDYA2形式ローカルビルドは成功済み
- 基準値は `docs/dya-studio/baseline.md` に記録済み
- フェーズ2の旧安定版比較では、機能Kconfig、DeviceTree、text、BSSが一致
- `zmk-west-commands` はビルド補助のみで、ファームウェア実行時コードを含まない
- GitHub Actions run `31585497890` で3成果物のビルドとartifact収集が成功
- Actions成果物3件はローカル生成物とSHA-256が完全一致
- フェーズ3で本番用Studio Lock、Unlockキー、Reserved Layer 4層を追加済み
- Fast KeymapとPhysical Layout RPCをSHA固定の外部モジュールで追加済み
- 右Central開発版を `_develop` 成果物として分離済み
- フェーズ3の4成果物はローカルDockerでクリーンビルド成功済み
- GitHub Actions run `31600347535` で4成果物のクリーンビルド成功済み
- CI成果物4件はローカル成果物とSHA-256が完全一致
- 既存7レイヤー、接続安定化設定、Idle 30秒、Deep Sleep 150分の維持を自動確認済み
- フェーズ3の詳細と実機確認手順は `docs/dya-studio/phase3.md` に記録済み
- DYA StudioでLock、Unlock、保存、トラックボール表示・動作の実機確認が完了
- フェーズ4でCustom Settingsコアを確認済みSHAへ固定済み
- Split Relayを左右、Custom Settings Studio RPCを右Centralだけで有効化済み
- フェーズ4の4成果物はローカルDockerでクリーンビルド成功済み
- 固定したCustom Settingsモジュールの公式テストは全件成功済み
- DeviceTreeはフェーズ3と完全一致し、Settings ResetのUF2も完全一致
- フェーズ4の詳細は `docs/dya-studio/phase4.md` に記録済み

## 再開時の確認

```bash
git status --short --branch
git branch --show-current
git rev-parse HEAD
git diff --check
```

想定と異なる変更が存在する場合は上書きせず、内容を確認してユーザーの変更を保持する。

ローカルビルドを行う場合はWSL2で次を確認する。

```bash
docker version
docker compose version
./scripts/zmk-build.sh --help
```

セットアップと成果物の場所は `DOCKER_BUILD.md` を参照する。

## Docker構成

通常は次のコマンドだけで、`config/west-dependency.yml` に適合する環境が自動選択される。

```bash
./scripts/zmk-build.sh
```

- `baseline`: ZMK v0.3／Zephyr 3.5用
- `dya`: DYA／Zephyr 4.1用
- リポジトリはコンテナ内で読み取り専用
- West依存物は環境別Docker Volumeへキャッシュ
- `build.yaml` の有効項目をローカルでも同じ名前で生成
- UF2またはBIN、ログ、サイズ、Kconfig、Devicetreeをホストへ保存

## CI/CDの扱い

1. ローカルDockerで変更対象または全成果物をビルドする
2. コミット後、Pull Request CIで全成果物をクリーンビルドする
3. CI失敗時はログを確認して同一フェーズ内で修正する
4. CI成功後にのみ、必要な実機確認をユーザーへ依頼する
5. 既定ブランチのCI成果物を配布候補とする

DYA2形式では、共通依存を `config/west-dependency.yml`、単独利用を `config/west-standalone.yml`、既存workspaceへの組み込みを `config/west-workspace.yml` で管理する。

## 次に行う作業

1. フェーズ4の変更をコミットしてpushする
2. GitHub Actionsの4成果物をローカル成果物と照合する
3. フェーズ4を完了状態へ更新し、フェーズ5の設計確認へ進む
