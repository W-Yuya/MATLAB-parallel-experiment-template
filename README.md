# 📘 `ProgressManager` クラス — 並列実験の進捗管理ツール
## 概要
`ProgressManager` は、MATLAB の並列実験（parfor など）における進捗状況を
リアルタイムで可視化・通知するための統合管理クラスです。

主な機能：
- waitbar による進捗表示
- TCP 通信による Web サーバーへの進捗通知
- 実験完了・中断時の自動処理
- 並列処理 (parfor) との安全な連携

## 🔧 ファイル構成
```
project_root/
├─ main.m                % 実験スクリプト
├─ parallel/
│   ├─ ProgressManager.m % 本体クラス
│   ├─ parallel_config.m % 設定ファイル（環境依存値をまとめる）
│   ├─ run_server.bat    % サーバー起動用バッチ
│   └─ progress_view/
│       └─ index.html    % ブラウザ表示用UI
```

## 🚀 基本的な使い方
```
clc; close all; clear;

% === path追加（parallelディレクトリへのパス） ===
addpath("./parallel/");

% === 実験数の設定 ===
num_experiment = 100;  % 並列実験の総数

% === ProgressManagerの初期化 ===
pm = ProgressManager(num_experiment);

% === 並列実験 ===
parfor expID = 1:num_experiment
    % 実験処理
    pause(0.1);  % （例）処理の代わりに遅延
    
    % 進捗更新
    pm.sendProgress(expID);
end

% === バッファを強制送信 ===
pm.flush();

% === 実験終了通知 ===
pm.sendFinish();
```

## ⚙️ parallel_config.m の役割と設定内容

`parallel_config.m` は、環境に依存するパラメータを集中管理する設定ファイルです。
このファイルを編集することで、他プロジェクトや他マシンでも簡単に流用できます。

### 設定例
```
% parallel_config.m
cfg = struct();

% --- 通信設定 ---
cfg.serverIP   = "127.0.0.1";
cfg.serverPort = 12345;
cfg.sendInterval = 1.0;     % [秒] サーバー送信間隔
cfg.bufferLimit = 10;       % バッファ送信閾値

% --- 表示設定 ---
cfg.debug_flag    = true;   % 標準出力を表示
cfg.view_waitbar  = true;   % MATLAB waitbarを表示
cfg.view_browser  = true;   % サーバーとブラウザを起動

% --- 実験ディレクトリ設定 ---
cfg.startServerDirName = "parallel";
cfg.serverLauncherBat  = "run_server.bat";
cfg.htmlFileName       = "progress_view/index.html";
```

### 自動読み込み

`ProgressManager` は初期化時に `parallel_config.m`を自動で読み込み、
上記の設定を内部に反映します。

そのため、通常は `ProgressManager(num_experiment)` の1行だけで動作します。

## 🧩 主なメソッド

|メソッド名|概要|
|---------|----|
|`ProgressManager(numExp, [rootDir])`| コンストラクタ。実験数とルートディレクトリを指定（省略時は実行位置）。|
|`sendInit()`| 初期化メッセージをサーバーに送信（通常は自動呼び出し）。|
|`sendProgress(expID, [workerID])`| 実験の進捗を1件追加。parfor 内で呼び出す。|
|`flush()` | バッファに溜まった進捗データをサーバーへ強制送信。|
|`sendFinish()`| 全実験終了通知。waitbarも自動で閉じる。|

## 💡 Tips / 注意点

- parfor 内で直接TCP送信しない\
  → sendProgress は DataQueue 経由で安全に非同期送信されます。
- Webブラウザを開きたくない場合\
  → parallel_config.m 内で cfg.view_browser = false に設定。
- waitbar非表示で軽量化したい場合\
  → cfg.view_waitbar = false に設定。
- 標準出力を抑制したい場合\
  → cfg.debug_flag = false に設定。
- 異なる環境での実行\
  → バッチファイル (run_server.bat) とポート番号 (serverPort) を環境に合わせて変更。

## 🧭 まとめ
| 機能	| 対応箇所 |
|-------|---------|
|Web進捗表示|`progress_view/index.html`|
|TCP通信|	`serverIP`, `serverPort`, `sendInterval`|
|バッファ管理|	`bufferLimit`, `flush()`|
|ローカル表示|	`waitbar`, `debug_flag`|
|設定管理|	`parallel_config.m`|

必要に応じて、`ProgressManager` はそのまま他の実験スクリプトに再利用可能です。

`parallel_config.m` だけを環境に合わせて更新すれば、追加設定なしで動作します。
