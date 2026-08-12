# DYA Studio対応 作業引き継ぎ

最終更新: 2026-08-12
対象ブランチ: `feature/dya-studio-full-support`
起点: `dev/custom-dya` (`0b44ea6`)
完了フェーズ: フェーズ1「DYA用ZMK／Zephyrへの基盤更新」
進行中フェーズ: フェーズ2「Manifest・CI・ビルドマトリクスの再構成」
次フェーズ: フェーズ3「ZMK Studioレベル1の完成」

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
- フェーズ2のManifest、ローカルビルド、CI再構成は実装済み
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
- フェーズ2のGitHub Actions結果はコミット・push後に確認する

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

1. フェーズ2の変更をコミットしてpushする
2. GitHub Actionsで3成果物と成果物名を確認する
3. フェーズ2の結果を `docs/dya-studio/phase2.md` と実装ToDoへ反映する
4. フェーズ3開始時にDYA Studioの現行要件を再確認する
5. 本番版のStudio Lockと、開発版のLock無効構成を分離して設計する
