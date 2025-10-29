%% parallel_config.m
% ProgressManager 用の設定ファイル

% --- 通信設定 ---
serverIP = "127.0.0.1";
serverPort = 12345;
sendInterval = 1;          % 秒
bufferLimit = 10;

% --- 表示設定 ---
debug_flag = true;
view_waitbar = true;
view_browser = true;

% --- 実験ディレクトリ設定 ---
startServerDir = string(pwd); % このファイルのディレクトリを取得
serverLauncherBat  = "run_server.bat";
htmlFileName       = "progress_view\index.html";
% experimentRootDir  = "desktop\experiment_root";
experimentRootDir = fileparts(startServerDir);