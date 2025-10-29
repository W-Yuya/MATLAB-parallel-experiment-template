# 🧩 MATLAB Parallel Experiment Template

並列数値実験の進捗をブラウザで可視化するテンプレート

## 🌟 概要

このリポジトリは、MATLAB の Parallel Computing Toolbox を用いた
並列数値実験の進捗をリアルタイムで可視化するテンプレートです。

最新版（R2025以降）では MATLAB 純正の[タスクビジュアライザ](https://jp.mathworks.com/help/simulink/slref/simulationmanager.html)が使える(?)ようですが、
R2022a では標準機能が不十分だったため、
Pythonサーバー＋ブラウザ表示で可視化する仕組みを作っています。

Simulink は…知りません（使えない）

## 💡 コンセプト

- 並列実験の進行状況をリアルタイムでブラウザ表示
- MATLAB のリソースを極力数値実験に集中（サーバー処理はPythonに委譲）
- シンプルな導入（`parallel/` フォルダをプロジェクトに追加するだけ）
- R2022aで動作確認済み

## ⚙️ 環境・前提

基本的には 並列クラスタのホストコンピュータ上での使用を想定しています。

```
MATLAB:
  R2022a
  Parallel Computing Toolbox

Python:
  3.11

OS：Windows のみ動作確認済み
```
MATLABはバージョンが違っても動くと思います。\
Pythonは...頑張ってください。\
※Pythonバージョンを指定した仮想環境の作成は[こちら](https://maku77.github.io/p/wozpogm/#:~:text=(.venv)%20%24%20deactivate-,%E7%89%B9%E5%AE%9A%E3%81%AE%E3%83%90%E3%83%BC%E3%82%B8%E3%83%A7%E3%83%B3%E3%81%AE%20Python%20%E3%82%92%E4%BD%BF%E3%81%86%E4%BB%AE%E6%83%B3%E7%92%B0%E5%A2%83%E3%82%92%E4%BD%9C%E6%88%90%E3%81%99%E3%82%8B,-venv%20%E7%92%B0%E5%A2%83%E5%86%85)が参考になります。

## 🧠 システム構成

このテンプレートは以下の3層構造になっています：

`Matlab → Pythonサーバー → HTMLブラウザ表示`

|層	|役割|
|---|----|
|MATLAB|	数値実験本体。進捗をPythonサーバーに通知|
|Python|	進捗情報を受け取り、整形してWeb配信|
|HTML|	ブラウザ上で進捗をリアルタイム可視化|

### 📁 ファイル構成

`parallel/`フォルダが本システムの中核です。

```
parallel/
├ venv/                # Python用仮想環境
├ progress_view/       # ブラウザ表示用HTML群
│   ├ index.html
│   ├ script.js
│   └ style.css
├ parallel_config.m    # ProgressManagerの設定ファイル
├ ProgressManager.m    # 進捗管理クラス (MATLAB側メイン)
├ run_server.bat       # サーバー起動スクリプト
└ server.py            # Pythonローカルサーバー
```

これらを以下のように配置しています：
```
experiment_root/
├ parallel/   # 本システム
├ src/        # 実験スクリプト群
└ main.m      # 実験のメインスクリプト
```

### 💡 補足:
<details>
<summary>なぜこんな構成にしたのか</summary>
MATLAB 側の計算リソースを圧迫しないよう、
Python が Web サーバーを立てて表示を担当します（本当にメモリ効率がいいのかは不明）。
    
つまるところ、ビジュアライズ専用ノード（ホストマシン）などで実行する場合は
MATLAB 内で完結させた方が無難です。
</details>

## 📊 ProgressManager クラスについて

`parallel/ProgressManager.m` は、
実験進捗とTCP通信を一元管理する中核クラスです。

- 主な機能
  - waitbar による進捗バー表示（オプション）
  - Python サーバーへの TCP 通信
  - 実験完了・中断時の自動処理
  - parfor 対応（DataQueue 経由）
- 主なメソッド一覧

|メソッド名|概要|
|---------|----|
|`ProgressManager(numExp, [configFile, rootDir])`|	コンストラクタ。実験数とコンフィグファイルのパス，ルートディレクトリを指定（省略可）|
|`sendInit()`|	サーバーに初期化通知を送信（通常自動）|
|`sendProgress(expID)`|	実験進捗を1件追加（parfor 内で呼ぶ）|
|`flush()`|	バッファを即時送信|
|`sendFinish()`|	全実験完了を通知し、UIを閉じる|

### ⚙️ 設定ファイル：parallel_config.m

環境依存の設定はすべてここにまとめられています。

**設定例**
```
%% parallel_config.m
% ProgressManager 用の設定ファイル

% --- 通信設定 ---
serverIP = "127.0.0.1";
serverPort = 12345;
sendInterval = 1;  % 秒
bufferLimit = 10;

% --- 表示設定 ---
debug_flag = true;
view_waitbar = true;
view_browser = true;

% --- サーバー/ブラウザ設定 ---
startServerDir = string(pwd); % このファイルのディレクトリを取得
serverLauncherBat  = "run_server.bat";
htmlFileName       = "progress_view\index.html";
experimentRootDir = fileparts(startServerDir);
```

### 自動読み込み

`ProgressManager` 初期化時に自動で読み込まれ、
環境に応じた設定を自動反映します。

通常は `ProgressManager(num_experiment)` の1行でOKです。

## 🧩 テンプレート（本リポジトリ）の使い方

このテンプレートでは、KLNMF を用いて観測行列を基底・係数に分解し、
指定回数反復した後のコスト関数を記録するサンプルを実装しています。

### 💻 テンプレート構成
```
experiment_root/
├ parallel/   # 本システム
│   └ ProgressManager.m
├ src/        # 実験本体のスクリプト群
│   └ experiment_manager.m
└ main.m      # 実験設定・呼び出し
```

### `main.m`

実験条件・データセットの設定など、事前処理を行います。

```
% pathの追加
addpath("./src/", "./parallel/")
```

重要なのはこの`addpath`で、`main.m`から両フォルダの `.m` ファイルを呼び出せるようになります。

### `experiment_manager.m`

実験を管理・進捗送信を行う中心スクリプトです。

`ProgressManager`クラスに関する記述

**初期化**
```
% num_experiment : 実験条件の総数
pm = ProgressManager(num_experiment);
```

**進捗更新とバッファ送信**
```
parfor expID = 1:num_experiment
    % ## 実験処理
    pm.sendProgress(expID); % 進捗更新
end
pm.flush(); % 残りのバッファを送信
```

**実験終了通知**
```
pm.sendFinish();
```

### 💬 ProgressManagerTips
- waitbar を非表示にする\
  → `view_waitbar = false;`
- ブラウザを開かない\
  → `view_browser = false;`
- 標準出力を抑制\
  → `debug_flag = false;`
- ポート変更\
  → `serverPort = 任意の値;`

## 🧭 まとめ
|機能    |    担当    |	ファイル    |
|--------|-----------|--------------|
|進捗管理|	MATLAB	|`ProgressManager.m|
|設定管理|	MATLAB	|`parallel_config.m|
|ローカルサーバー|	Python	| `server.py`|
|ビジュアライズ|	Web	|`progress_view/index.html`|
|サーバー起動|	Windows|	'run_server.bat'|

このテンプレートを導入すれば、parforをビジュアル的に監視できます。\
Pythonサーバーやweb側は適当なので、使いやすいように変更してみてください。
