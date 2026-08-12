# DYA Studio フル対応 実装 ToDo

最終更新: 2026-08-12  
起点ブランチ: `dev/custom-dya` (`0b44ea6`)
実装ブランチ: `feature/dya-studio-full-support`
対象キーボード: Torabo Tsuki LP  
対象DYA Studio: 安定版を基準とし、実装開始時にバージョンを再確認する

引き継ぎ資料: [`DYA_STUDIO_WSL_HANDOFF.md`](DYA_STUDIO_WSL_HANDOFF.md)
ローカルビルド: [`DOCKER_BUILD.md`](DOCKER_BUILD.md)

## 目的

現在のキーマップ、レイヤー、Auto Mouse、スクロール、PAW3222、IQS7211E、分割構成、非LiPo電池管理を維持したまま、DYA Studioの標準機能とCustom Studio Protocol機能へ段階的に対応する。

本番用ファームウェアと開発用ファームウェアを分離し、Devtoolやキー入力監視などの強力な開発機能を本番用へ含めない。

## 運用ルール

- [ ] 調査、設計、編集、静的検査、Git操作は、リポジトリを安全に扱える環境で進めてよい
- [ ] ZMK／Zephyrのローカルビルドは、WSL2から公式ZMK Dockerイメージを使用する構成を標準とする
- [ ] WSL Dockerが利用できない場合も編集作業は継続できるが、ローカルビルド項目を成功扱いにしない
- [ ] Windowsネイティブ環境へZMK／Zephyrツールチェーンを直接導入しない
- [ ] ローカルDockerビルドは高速な反復確認に使用し、最終的な自動検証と配布用成果物はCI/CDを正とする
- [ ] ローカルビルド成功だけではフェーズの最終合格にせず、該当するPull Requestまたは既定ブランチのCI成功を確認する
- [ ] CI/CDではクリーン環境から `build.yaml` の必須成果物をすべてビルドする
- [ ] 作業再開時は、先に `DYA_STUDIO_WSL_HANDOFF.md` と `DOCKER_BUILD.md` を確認する
- [ ] 実装中は、このファイルを各フェーズの開始時・検証時・完了時に更新する
- [ ] 各フェーズの変更は、ほかのフェーズと混ぜずに日本語のコミットメッセージでコミットする
- [ ] コード変更前に作業ツリーを確認し、ユーザーの未コミット変更を保持する
- [ ] DYA Studio、ZMK、Zephyr、外部モジュールの仕様は、実装するフェーズの開始時に公式情報を再確認する
- [ ] `main` 等の可変ブランチは調査・試作にのみ使い、採用時は実機検証済みコミットSHAへ固定する
- [ ] 各フェーズで、可能な限りビルド・静的検査・テストをCodexが完了してから実機確認を依頼する
- [ ] 実機確認が必要なフェーズは、Codexの自動検証がすべて成功するまでユーザーへ依頼しない
- [ ] 実機確認待ちの場合は、チェックを未完了のまま残し、結果・使用ファームウェア・確認日を記録する
- [ ] 実機確認で重大な回帰があった場合は次フェーズへ進まず、そのフェーズ内で修正する
- [ ] 各フェーズのコミット前に本ファイルの進捗を更新する

### 担当表記

- **Codex**: コード変更、依存調査、ビルド、静的検査、テスト、成果物整理
- **ユーザー**: 実機への書き込み、物理入力、Bluetooth接続など、実機でしか確認できない作業
- **共同**: Codexが手順と判定基準を提示し、ユーザーが結果を返し、Codexが記録・判断する作業

### フェーズの完了条件

1. Codex担当ToDoがすべて完了している
2. 自動検証がすべて成功している
3. 必須のユーザー実機確認が完了している、または後続を妨げない「延期」として理由が記録されている
4. 既知の制約と残課題が本ファイルへ記録されている
5. フェーズの変更とToDo更新がコミットされている

## 現状維持の必須要件

- [ ] Mレイアウトを既定として維持する
- [ ] 52キーの位置とPhysical Layoutの対応を維持する
- [ ] 既存7レイヤーの番号と役割を維持する
  - `0`: Base
  - `1`: Mouse
  - `2`: Lower
  - `3`: Mid
  - `4`: Raise
  - `5`: Scroll
  - `6`: Adjust
- [ ] 日本語キーボード用のキー変換定義を維持する
- [ ] `MID + RAISE -> ADJUST` のConditional Layerを維持する
- [ ] Bluetoothクリアコンボを維持する
- [ ] 左右のAuto Mouse設定を維持する
  - 左: Mouseレイヤー1、解除800ms
  - 右: Mouseレイヤー1、解除500ms
- [ ] Scrollレイヤー5、X軸反転、スクロール倍率 `1/64` を維持する
- [ ] マウスボタン4・5を維持する
- [ ] PAW3222、IQS7211E、Split Inputの既存構成を維持する
- [ ] Status LED、CDC ACM Bootloader Trigger、非LiPo電池管理を維持する
- [ ] 左Peripheral＋右Centralを既定の配布構成として維持する

---

## フェーズ0: ベースラインの固定

状態: 完了

### Codex

- [x] 実装用ブランチを `dev/custom-dya` から作成する
- [x] WSL2からDockerとDocker Compose v2を利用できることを確認する
- [x] Dockerイメージ、West manifest、ビルドスクリプトのバージョンを基準記録へ残す
- [x] 起点コミット、リモート参照、DYA Studio安定版を記録する
- [x] 現在有効な `build.yaml` の成果物を一覧化する
- [x] 現在のキーマップ、Devicetree、Kconfig、snippet構成を記録する
- [x] 既存挙動の回帰チェックリストを作成する
- [x] 公式ZMKイメージを使うWSL Dockerビルド構成を追加する
- [x] WSL Dockerで、現行構成を変更せずにビルドできることを確認する
- [x] 現行の左Peripheral、右Central、Settings Resetをビルドする
- [x] ビルドログ、UF2、ファームウェアサイズを基準値として保存する
- [x] 生成済み `.config` とDevicetreeを保存する

### 自動検証

- [x] ローカルDockerで全成果物がビルド成功する
- [x] GitHub Actionsのクリーン環境で全成果物がビルド成功する
- [x] 左Peripheralがビルド成功する
- [x] 右Centralがビルド成功する
- [x] Settings Resetがビルド成功する
- [x] 生成物名と対象board/shield/snippetが期待どおりである
- [x] 作業ツリーに意図しない生成物が追加されていない

### ユーザー実機確認

このフェーズの実機確認は原則不要。現在のファームウェアに既知の不具合がある場合のみ、実装前に申告する。

### コミット

- [x] `WSL Dockerビルド環境を整備`（環境整備とローカル基準値の中間コミット）
- [x] `DYA Studio対応前の基準状態を整備`

---

## フェーズ1: DYA用ZMK／Zephyrへの基盤更新

状態: 未着手

### Codex

- [ ] DYA Studio現行ガイドの推奨ZMK／Zephyrを再確認する
- [ ] `cormoran/zmk#main+dya` の採用候補SHAを記録する
- [ ] `cormoran/zephyr#v4.1.0+zmk-fixes+nrf-half-duplex-uart` の採用候補SHAを記録する
- [ ] `config/west.yml` を候補revisionへ更新する
- [ ] DYA機能をまだ有効化せず、既存機能だけでビルドする
- [ ] 次の既存依存のZephyr 4.1互換性を確認する
  - [ ] `zmk-component-bmp-boost`
  - [ ] `zmk-feature-status-led`
  - [ ] `zmk-driver-paw3222`
  - [ ] `zmk-driver-iqs7211e`
  - [ ] `zmk-feature-cdc-acm-bootloader-trigger`
  - [ ] `zmk-feature-non-lipo-battery-management`
- [ ] 非互換があれば最小限の前方移植を行う
- [ ] コンパイル警告と非推奨設定を整理する
- [ ] 基準値とファームウェアサイズを比較する

### 自動検証

- [ ] 左Peripheralがクリーンビルド成功する
- [ ] 右Centralがクリーンビルド成功する
- [ ] Settings Resetがクリーンビルド成功する
- [ ] PAW3222とIQS7211EのDevicetree nodeが生成物に存在する
- [ ] `auto_mouse_layer` と既存input processor chainが生成物に存在する
- [ ] 既存7レイヤーとPhysical Layoutが生成物に存在する
- [ ] RAM／Flash使用量が許容範囲内である

### ユーザー実機確認 — 必須ゲート

Codexの全ビルド成功後に、互換性確認を1回だけ依頼する。

- [ ] **ユーザー**: 左右へフェーズ1のUF2を書き込む
- [ ] **ユーザー**: 全キーが入力できることを確認する
- [ ] **ユーザー**: 左右分割通信を確認する
- [ ] **ユーザー**: ポインター移動、Auto Mouse、Scrollレイヤー、左右クリック、MB4／MB5を確認する
- [ ] **ユーザー**: Sleep復帰、USB、Bluetooth接続を確認する
- [ ] **共同**: 結果と不具合を本ファイルへ記録する

### コミット

- [ ] `DYA対応ZMKとZephyrへ基盤を更新`
- [ ] 実機確認後に必要なら `基盤更新後の実機確認結果を反映`

---

## フェーズ2: Manifest・CI・ビルドマトリクスの再構成

状態: 未着手

### Codex

- [ ] DYA2参照実装のManifest構成を再確認する
- [ ] 共通依存を `west-dependency.yml` へ分離する
- [ ] standalone用Manifestを追加する
- [ ] workspace用Manifestを追加する
- [ ] GitHub Actionsを `west zmk-build` ベースへ移行する
- [ ] 依存キャッシュを設定する
- [ ] 本番用と開発用の成果物名を区別する
- [ ] 現時点で有効な構成だけを必須ビルドにする
- [ ] 将来構成はコメントではなく、明示的な任意matrixまたは別build定義として管理する

### 自動検証

- [ ] ローカルのstandalone構成でwest初期化できる
- [ ] 左Peripheral、右Central、Settings Resetを一括ビルドできる
- [ ] CI用YAMLの構文が正しい
- [ ] GitHub Actionsが成功する
- [ ] 成果物に対象を識別できる名前が付く

### ユーザー実機確認

不要。フェーズ1と同じバイナリ設定になることを自動比較する。

### コミット

- [ ] `DYA対応向けにManifestとCIを再構成`

---

## フェーズ3: ZMK Studioレベル1の完成

状態: 未着手

### Codex

- [ ] `CONFIG_ZMK_STUDIO_LOCKING=n` を本番設定から削除する
- [ ] Adjustレイヤーの安全な位置へ `&studio_unlock` を追加する
- [ ] 既存7レイヤーの番号を維持する
- [ ] Studio用のReserved Layerを末尾へ追加する
- [ ] Reserved Layer数をDYA Studioの現行要件に合わせる
- [ ] M Physical Layoutと52キーのposition mapを検証する
- [ ] `zmk-feature-fast-keymap` を追加する
- [ ] Fast KeymapのRPCとDefault Layer読取を有効にする
- [ ] `zmk-feature-module-physical-layout` を追加する
- [ ] トラックボール／トラックパッドの物理表示nodeを追加する
- [ ] 開発用にStudio Lock無効版を別成果物として用意する

### 自動検証

- [ ] 本番版でStudio Lockが有効である
- [ ] 開発版だけStudio Lockが無効である
- [ ] `&studio_unlock` が期待するキー位置にある
- [ ] 既存7レイヤーの内容と番号が変わっていない
- [ ] Reserved Layerが既存レイヤーの後ろにある
- [ ] Fast KeymapとPhysical Layout RPCが有効である
- [ ] 全成果物がビルド成功する

### ユーザー実機確認 — 必須ゲート

- [ ] **ユーザー**: USBでDYA Studioへ接続する
- [ ] **ユーザー**: ロック中にKeymap変更が拒否されることを確認する
- [ ] **ユーザー**: AdjustレイヤーからUnlockする
- [ ] **ユーザー**: Keymapを1キーだけ変更し、保存・再起動・復元を確認する
- [ ] **ユーザー**: Mレイアウトの表示位置が実機と一致することを確認する
- [ ] **共同**: 変更したキーを元へ戻し、結果を記録する

### コミット

- [ ] `ZMK Studioの安全なキーマップ編集に対応`
- [ ] 実機確認後に必要なら `ZMK Studio実機確認結果を反映`

---

## フェーズ4: Custom Studio Protocolコア

状態: 未着手

### Codex

- [ ] `zmk-feature-custom-settings` を追加する
- [ ] Split Relayを左右で有効にする
- [ ] Custom Settings RPCをCentralだけで有効にする
- [ ] `zmk-feature-fast-keymap` のDYA拡張設定を確定する
- [ ] スタック／バッファ設定を追加する
- [ ] KSCAN Diagnosticsを見越し、Split Relay payloadを256で検証する
- [ ] 保存デバウンスを設定する
- [ ] Memory Only／Save／Discard／Resetの利用方針を文書化する
- [ ] 本番版では保護対象の読み書きにUnlockを要求する

### 自動検証

- [ ] Central／PeripheralのKconfig依存が正しい
- [ ] Peripheralへ不要なStudio RPCがリンクされていない
- [ ] 左右のビルドが成功する
- [ ] RAM／Flash使用量をフェーズ3と比較する
- [ ] Custom Settingsのモジュールテストまたは利用可能な上流テストを実行する
- [ ] 設定リセット用成果物がビルドできる

### ユーザー実機確認

原則不要。フェーズ5以降の画面を使った確認にまとめる。

### コミット

- [ ] `Custom Studio Protocolの基盤を追加`

---

## フェーズ5: Macro・Combo・Input Stream

状態: 未着手

### Codex

- [ ] `zmk-feature-runtime-macro` を追加する
- [ ] `zmk-feature-runtime-combo` を追加する
- [ ] `zmk-feature-input-stream` を追加する
- [ ] Runtime Macro用behaviorをkeymapへincludeする
- [ ] Runtime Macro用の空きslot／既定macro方針を決める
- [ ] 既存BT ClearコンボをCompile-time Defaultとして維持する
- [ ] Macro／Comboの上限をRAM使用量に合わせて設定する
- [ ] Input Streamを開発版だけにするか、Unlock必須の本番機能にするか決定する
- [ ] Factory ResetでRuntime設定が消去されることを自動確認する

### 自動検証

- [ ] Macro／Combo／Input Stream有効版がビルド成功する
- [ ] 既存コンボのDevicetree定義が維持されている
- [ ] RPC bufferが最大payloadを収容できる
- [ ] 上流のFirmware／Web UIテストのうち実行可能なものが成功する
- [ ] RAM／Flash使用量が許容範囲内である

### ユーザー実機確認 — まとめて1回

- [ ] **ユーザー**: Runtime Macroを作成・実行する
- [ ] **ユーザー**: Macroを保存し、再起動後に復元されることを確認する
- [ ] **ユーザー**: Runtime Comboを作成・実行する
- [ ] **ユーザー**: 既存BT Clearコンボが従来どおり動作することを確認する
- [ ] **ユーザー**: Input Streamで押下位置とレイヤー変更が正しく表示されることを確認する
- [ ] **共同**: テスト用Macro／Comboを削除し、結果を記録する

### コミット

- [ ] `DYA Studioのマクロとコンボ編集に対応`
- [ ] 実機確認後に必要なら `マクロとコンボの実機確認結果を反映`

---

## フェーズ6: Runtime Input Processorへの移行

状態: 未着手

### Codex

- [ ] 公式派生ブランチのRuntime Input Processor移行差分を再確認する
- [ ] `zmk-module-runtime-input-processor` を追加する
- [ ] 現在の静的処理を表す回帰テストまたはDevicetree検査を追加する
- [ ] Mouse Runtime Input Processorを追加する
- [ ] Scroll Runtime Input Processorを追加する
- [ ] 右Auto Mouseの既定値を500msにする
- [ ] 左Auto Mouseの既定値を800msにする
- [ ] Scrollの既定active layerを5にする
- [ ] X軸反転を維持する
- [ ] スクロール倍率 `1/64` 相当を維持する
- [ ] `process-next` 相当のイベント処理順を維持する
- [ ] Local／Split Input Listenerの両方に適用する
- [ ] 旧 `auto_mouse_layer` を安全に削除する

### 自動検証

- [ ] 左右overlayのRuntime Processor参照が解決する
- [ ] Local／Split構成がすべてビルド成功する
- [ ] Processorの既定値が現在値と一致する
- [ ] 設定範囲と保存先がFirmware側で検証される
- [ ] RAM／Flash／スタック使用量が許容範囲内である
- [ ] 上流Runtime Input Processorテストが実行可能な範囲で成功する

### ユーザー実機確認 — 必須ゲート

- [ ] **ユーザー**: 通常のポインター移動を確認する
- [ ] **ユーザー**: 左右それぞれのAuto Mouseを確認する
- [ ] **ユーザー**: Scrollレイヤーと方向・速度を確認する
- [ ] **ユーザー**: DYA Studioから感度、回転、軸反転、対象レイヤーを一項目ずつ変更する
- [ ] **ユーザー**: Save／Discard／Resetと再起動後の復元を確認する
- [ ] **ユーザー**: 左右クリック、Middle、MB4、MB5を確認する
- [ ] **共同**: 既定値へ戻して結果を記録する

### コミット

- [ ] `ポインター設定をRuntime Input Processorへ移行`
- [ ] 実機確認後に必要なら `ポインター実機確認結果を反映`

---

## フェーズ7: Connection・Default Layer・Settings

状態: 未着手

### Codex

- [ ] `zmk-module-ble-management` を追加する
- [ ] `zmk-module-settings-rpc` を追加する
- [ ] `zmk-feature-default-layer@codex/custom-rpc-rewrite` を追加する
- [ ] `zmk-feature-os-detection` を追加する
- [ ] BLE profile数を現行設定と一致させる
- [ ] Idle／Deep Sleepの既定値を現在値と一致させる
- [ ] 左右別／一括設定の対象を明記する
- [ ] 既存レイヤー1～6をDefault Layerに誤指定できない設計にする
- [ ] 許可レイヤー方式またはOS別Baseレイヤー方式を決定する
- [ ] 手動OS overrideを本番版で有効にする
- [ ] OS自動検出は開発版でのみ有効にする
- [ ] 本番昇格条件をWindows／macOS／Linux／iOS／Android別に記録する

### 自動検証

- [ ] BLE Management／Settings／Default Layerがビルド成功する
- [ ] レイヤー範囲外設定が拒否される
- [ ] Base以外を誤って常時有効化しない
- [ ] Centralのみで接続先判定とRPCが動作する構成になっている
- [ ] Settings Reset成果物がビルド成功する
- [ ] RAM／Flash／スタック使用量が許容範囲内である

### ユーザー実機確認 — 必須ゲート

- [ ] **ユーザー**: BLE profileの一覧、名称変更、切替を確認する
- [ ] **ユーザー**: テスト用profileの解除を確認する
- [ ] **ユーザー**: USBとBLEの優先順位を確認する
- [ ] **ユーザー**: Sleep時間を変更し、左右への適用と復元を確認する
- [ ] **ユーザー**: 手動OS overrideを確認する
- [ ] **ユーザー**: 対応可能なOSについて自動検出の結果を報告する
- [ ] **共同**: 未検証OSと本番版への採否を記録する

### コミット

- [ ] `DYA Studioの接続管理と本体設定に対応`
- [ ] 実機確認後に必要なら `接続管理と設定の実機確認結果を反映`

---

## フェーズ8: 診断機能と開発版の分離

状態: 未着手

### Codex

- [ ] `zmk-feature-device-info` を追加する
- [ ] `zmk-feature-watchdog` を追加する
- [ ] `zmk-feature-kscan-diagnostics` を追加する
- [ ] KSCAN Diagnosticsを左右で有効にする
- [ ] Split Relay payload 256を左右へ明示する
- [ ] Device InfoをUnlock必須にする
- [ ] WatchdogのFatal Handler競合を確認する
- [ ] Watchdog保存上限とFlash wear方針を設定する
- [ ] 開発版だけに `zmk-module-devtool` を追加する
- [ ] 開発版だけに `zmk-feature-zephyr-setting-expose` を追加する
- [ ] Devtoolのキー注入・Event Tap・Log Captureの採用範囲を限定する
- [ ] 本番成果物にDevtoolが含まれないことを検査する

### 自動検証

- [ ] 本番版と開発版が両方ビルド成功する
- [ ] 本番版のKconfigにDevtool関連symbolがない
- [ ] Device Info／Watchdog／KSCANのRPCがCentralへ入る
- [ ] Peripheral側に必要な診断応答機能が入る
- [ ] 上流モジュールテストが実行可能な範囲で成功する
- [ ] RAM／Flash／スタック使用量が許容範囲内である

### ユーザー実機確認

必須項目を1回にまとめ、危険な障害注入は行わない。

- [ ] **ユーザー**: Device Infoとサポート用JSONを取得する
- [ ] **ユーザー**: KSCAN画面で全キーのpositionを確認する
- [ ] **ユーザー**: チャタリング統計のリセットを確認する
- [ ] **ユーザー**: Watchdog画面が開くことを確認する
- [ ] **ユーザー**: 開発版だけDevtoolが表示されることを確認する
- [ ] **共同**: Peripheral配線表示など公式UI未完成部分を制約として記録する

### コミット

- [ ] `DYA Studioの診断機能と開発用機能を追加`
- [ ] 実機確認後に必要なら `診断機能の実機確認結果を反映`

---

## フェーズ9: PAW3222・IQS7211Eの独自RPC

状態: 未着手

### 共通方針

- [ ] DYA公式のCustom Studio RPCテンプレートを再確認する
- [ ] 既存モジュールで代替できない項目だけを独自実装する
- [ ] 公開する値の範囲、単位、初期値、保存要否を定義する
- [ ] 読み書きはStudio Unlock必須にする
- [ ] subsystem IDの重複を確認する
- [ ] protobufのfield番号を固定し、再利用しない
- [ ] unknown field／unsupported featureを安全に処理する
- [ ] 再利用可能なセンサーRPCは独立モジュール化する

### PAW3222 — Codex

- [ ] 現ドライバーのRuntime APIを再確認する
- [ ] CPIのGet／Set／Save／Discard／Resetを実装する
- [ ] Force AwakeのGet／Set／Save／Discard／Resetを実装する
- [ ] CPI範囲をFirmware側で検証する
- [ ] Runtime Input Processorと責務が重複しないよう整理する
- [ ] Firmware、build、Web UIテストを追加する

### IQS7211E — Codex

- [ ] 安全にRuntime変更可能な項目を確定する
- [ ] 必要なRuntime Setter APIをドライバーへ追加する
- [ ] 慣性有効化、減衰率、停止しきい値を公開する
- [ ] 横スクロールゾーンと方向反転の公開可否を判断する
- [ ] Scroller ModeのRuntime変更可否を判断する
- [ ] 217バイト初期化データ全体はWeb編集対象外とする
- [ ] Firmware、build、Web UIテストを追加する

### 自動検証

- [ ] 独自モジュールのFirmware unit testが成功する
- [ ] 独自モジュールのbuild testが成功する
- [ ] Web UI unit testが成功する
- [ ] 不正範囲、ロック中書込、未対応deviceが適切に拒否される
- [ ] 本リポジトリの全成果物がビルド成功する
- [ ] RAM／Flash／スタック使用量が許容範囲内である

### ユーザー実機確認 — 必須ゲート

- [ ] **ユーザー**: PAW3222のCPI変更と再起動後の復元を確認する
- [ ] **ユーザー**: PAW3222のForce Awake変更を確認する
- [ ] **ユーザー**: IQS7211Eの公開設定を一項目ずつ確認する
- [ ] **ユーザー**: IQS7211Eのタップ、縦横スクロール、慣性を確認する
- [ ] **共同**: 安全な既定値へ戻し、結果を記録する

### コミット

- [ ] `PAW3222のDYA Studio設定モジュールを追加`
- [ ] `IQS7211EのDYA Studio設定モジュールを追加`
- [ ] 実機確認後に必要なら `ポインティングデバイスRPCの実機確認結果を反映`

---

## フェーズ10: Battery Historyの評価

状態: 未着手

### Codex

- [ ] Torabo公式派生ブランチで無効化された理由を再確認する
- [ ] DYA2の現行採用状況を再確認する
- [ ] `zmk-module-battery-history` の最新実装と既知問題を確認する
- [ ] 開発版だけでBattery Historyを有効にする
- [ ] 非LiPo電池管理との値変換を確認する
- [ ] 保存間隔、最大件数、USB給電時の扱いを設定する
- [ ] Flash書き込み頻度を見積もる
- [ ] Watchdog／入力処理への影響を可能な範囲で計測する

### 自動検証

- [ ] Battery History有効版がビルド成功する
- [ ] 無効版とのRAM／Flash差分を記録する
- [ ] モジュールテストが成功する
- [ ] 保存間隔と最大件数からFlash wearを見積もる

### ユーザー実機確認 — 採用判断用

- [ ] **ユーザー**: 開発版を一定期間使用する
- [ ] **ユーザー**: 履歴記録、再起動後の復元、履歴クリアを確認する
- [ ] **ユーザー**: 入力遅延、フリーズ、予期しない再起動の有無を報告する
- [ ] **共同**: 本番版へ採用／保留／不採用を決定する

### コミット

- [ ] `Battery Historyの評価構成を追加`
- [ ] 採用時: `Battery Historyを本番構成へ追加`
- [ ] 保留／不採用時: 理由を本ファイルへ記録する

---

## フェーズ11: 最終安定化・依存固定・リリース候補

状態: 未着手

### Codex

- [ ] DYA Studio安定版で表示される全タブと対応機能を棚卸しする
- [ ] 各依存を検証済みコミットSHAへ固定する
- [ ] 本番版と開発版のKconfig差分をレビューする
- [ ] すべての成果物をクリーンビルドする
- [ ] 全CIを成功させる
- [ ] RAM／Flash／各thread stackの余裕を記録する
- [ ] Factory Resetと設定移行方針を文書化する
- [ ] 旧ファームウェアへ戻す手順を文書化する
- [ ] READMEへDYA Studio接続方法、Unlock方法、対応機能、制約を追加する
- [ ] 実機確認用チェックシートと成果物一覧を作成する
- [ ] 未完成の公式機能・未検証OS・保留機能を明記する

### 自動検証

- [ ] 本番・右Centralがクリーンビルド成功する
- [ ] 本番・左Peripheralがクリーンビルド成功する
- [ ] 開発・右Centralがクリーンビルド成功する
- [ ] 開発・左Peripheralがクリーンビルド成功する
- [ ] Settings Resetがクリーンビルド成功する
- [ ] 対応対象に含めた追加構成がすべてビルド成功する
- [ ] 本番版にDevtool、キー注入、Event Tap、無条件Unlockが含まれない
- [ ] すべての依存がSHA固定されている
- [ ] Git差分に生成物や秘密情報が含まれない

### ユーザー最終実機確認 — 必須

Codexが検証済み成果物と短い確認手順を提示し、確認を1回にまとめる。

- [ ] **ユーザー**: 本番版を左右へ書き込む
- [ ] **ユーザー**: 現状維持の必須要件を一通り確認する
- [ ] **ユーザー**: USB／BLEでDYA Studioへ接続する
- [ ] **ユーザー**: Keymap／Macro／Comboを確認する
- [ ] **ユーザー**: Trackball／Trackpad設定を確認する
- [ ] **ユーザー**: Connection／Settingsを確認する
- [ ] **ユーザー**: Diagnosticsを確認する
- [ ] **ユーザー**: 再起動、左右再接続、Sleep復帰を確認する
- [ ] **共同**: 最終結果、既知の制約、リリース可否を記録する

### コミット

- [ ] `DYA Studioフル対応を最終調整`
- [ ] 実機確認後: `DYA Studio対応の最終検証結果を反映`

---

## 実機確認依頼テンプレート

各ゲートでは、Codexが次の形式で依頼を作成する。

```text
対象フェーズ:
書き込む成果物:
対象側（Central／Peripheral）:
事前条件:
確認手順:
期待結果:
失敗時に記録してほしい内容:
元へ戻す手順:
```

## 検証記録

| 日付 | フェーズ | 検証種別 | 対象コミット／成果物 | 結果 | 備考 |
|---|---|---|---|---|---|
| - | - | - | - | - | - |

## 既知の制約・判断待ち

- DYA StudioのPAW3222／IQS7211E専用画面は現時点で存在しないため、まずCustom Subsystemsとして実装する
- ネイティブTrackball画面への統合にはDYA Studio本体側の変更が必要
- OS Detectionは公式README上も実験的要素があるため、実機確認済みOSだけを本番対象とする
- KSCAN DiagnosticsのPeripheral配線表示には公式UI側の未完成部分がある
- Battery HistoryはTorabo公式派生ブランチとDYA2で無効化実績があるため、評価完了まで本番へ入れない
- `main+dya` と各モジュールの `main` は変動するため、最終的に検証済みSHAへ固定する

## 完了定義

- [ ] 現状維持の必須要件をすべて満たす
- [ ] USB／BLEの両方からDYA Studioへ接続できる
- [ ] Keymap／Macro／Comboを編集・保存・復元できる
- [ ] Runtime Input ProcessorをWebから設定できる
- [ ] PAW3222とIQS7211Eの安全な設定をWebから変更できる
- [ ] BLE profile、Default Layer、Settingsを管理できる
- [ ] Device Info、Watchdog、KSCAN Diagnosticsを利用できる
- [ ] Factory Resetと設定復元が正常に動作する
- [ ] 本番版と開発版が明確に分離されている
- [ ] 全ビルド・CI・自動テストが成功する
- [ ] 必須の実機確認が完了している
- [ ] すべての依存が検証済みSHAへ固定されている
- [ ] READMEと本ToDoが最終状態へ更新されている
