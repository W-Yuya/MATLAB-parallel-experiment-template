classdef ProgressManager < handle
    % ProgressManager: 実験進捗とTCP通信を一元管理するクラス
    %
    % 使用例:
    %   pm = ProgressManager(num_experiments, experiment_root_dir);
    %   pm.sendInit();
    %   parfor idx = 1:nThisChunk
    %       ...
    %       pm.sendProgress(expID, workerID);
    %   end
    %   pm.flush();
    %   pm.sendFinish();
    %
    % ※ experiment_manager.m などで複数実験に共通利用可能

    properties
        % === configFile ===
        configFile string = "./parallel/parallel_config.m"

        % === 設定値 ===
        serverIP (1,1) string
        serverPort (1,1) double
        sendInterval (1,1) double
        buffer cell = {}
        bufferLimit (1,1) double
        lastSendTime
        numExperiments (1,1) double = 0

        % === 表示設定 ===
        debug_flag (1,1) logical
        view_waitbar (1,1) logical
        view_browser (1,1) logical

        % === 通信/UI関連 ===
        client
        dataQueue
        waitbarHandle
        tStart
        progressCount (1,1) double = 0

        % === 実験ディレクトリ/ファイル ===
        experimentRootDir string
        startServerDir string
        serverLauncherBat string
        htmlFileName string
    end

    methods
        %% === コンストラクタ ===
        function obj = ProgressManager(numExperiments, configFile, experimentRootDir)
            % parallel_config.mを読み込み
            if nargin > 1 && ~ismepty(configFile)
                config = obj.loadConfig(configFile);
            else
                config = obj.loadConfig();
            end

            % --- 設定値の読み込み ---
            obj.serverIP        = config.serverIP;
            obj.serverPort      = config.serverPort;
            obj.sendInterval    = config.sendInterval;
            obj.bufferLimit     = config.bufferLimit;
            obj.debug_flag      = config.debug_flag;
            obj.view_waitbar    = config.view_waitbar;
            obj.view_browser    = config.view_browser;
            obj.startServerDir = config.startServerDir;
            obj.serverLauncherBat  = config.serverLauncherBat;
            obj.htmlFileName       = config.htmlFileName;

            % --- 実験ディレクトリ設定 ---
            if nargin > 2 && ~isempty(experimentRootDir)
                obj.experimentRootDir = string(experimentRootDir);
            elseif ~isempty(config.experimentRootDir)
                obj.experimentRootDir = config.experimentRootDir;
            else
                obj.experimentRootDir = string(pwd);
            end
            obj.numExperiments = numExperiments;

            % --- サーバー起動/接続 ---
            if obj.view_browser
                obj.initServer();
                obj.connect();
                obj.sendInit();
            end

            % --- waitbar/UI 初期化 ---
            obj.setupProgressUI();
        end

        %% === 設定ファイル読み込み ===
        function config = loadConfig(obj, configFile)
            if nargin > 1 && ~isempty(configFile) 
                obj.configFile = configFile;
            end
            if ~isfile(obj.configFile)
                error("設定ファイル %s が見つかりません。", obj.configFile);
            end
            run(obj.configFile);
            config = struct();
            vars = whos;
            for v = {vars.name}
                config.(v{1}) = eval(v{1});
            end
        end

        %% === サーバー起動 & ブラウザ表示 ===
        function initServer(obj)
            start_cmd = "start " + string(fullfile(obj.startServerDir, obj.serverLauncherBat)) ...
                       + " " + string(obj.startServerDir);
            if obj.debug_flag
                fprintf("[Server] 起動コマンド: %s\n", start_cmd);
            end
            system(start_cmd);
            pause(3); % サーバー起動待機

            % ブラウザ表示
            html_path = fullfile(obj.startServerDir, obj.htmlFileName);
            if obj.debug_flag
                fprintf("[Server] WebView: %s\n", html_path);
            end
            web(html_path, '-browser');
        end

        %% === TCP接続確立 ===
        function connect(obj)
            obj.client = tcpclient(obj.serverIP, obj.serverPort, 'Timeout', 1);
            if obj.debug_flag
                fprintf("[Client] TCP接続完了 (%s:%d)\n", obj.serverIP, obj.serverPort);
            end
        end

        %% === UI初期化 ===
        function setupProgressUI(obj)
            obj.dataQueue = parallel.pool.DataQueue;
            if obj.view_waitbar
                obj.waitbarHandle = waitbar(0, 'Initializing...');
            end
            obj.tStart = tic;
            afterEach(obj.dataQueue, @(x)obj.updateProgress(x));
        end

        %% === 開始時間の再設定 ===
        function resetStartTime(obj)
            obj.tStart = tic;
            % TODO: server側の再設定処理. sendInitの再実行でリセットできるはず
        end

        %% === INITメッセージ送信 ===
        function sendInit(obj)
            if ~obj.view_browser
                if obj.debug_flag; fprintf("[INIT] サーバー未使用のためスキップ\n"); end
                return
            end
            msg = struct('type', 'INIT', 'num_experiment', obj.numExperiments);
            obj.send(jsonencode(msg));
            if obj.debug_flag
                fprintf("[INIT] 実験数: %d\n", obj.numExperiments);
            end
        end

        %% === PROGRESS送信 ===
        function sendProgress(obj, expID)
            wid_str = getCurrentWorkerId();
            data = struct('type', 'PROGRESS', 'task_id', expID, 'worker_id', wid_str);
            send(obj.dataQueue, data);
        end

        %% === FLUSH送信 ===
        function flush(obj)
            obj.sendBuffered('FLUSH');
        end

        %% === FINISH送信 ===
        function sendFinish(obj)
            msg = struct('type', 'FINISH');
            if obj.view_browser
                obj.send(jsonencode(msg));
                if obj.debug_flag
                    fprintf("[FINISH] 全実験完了を通知しました。\n");
                end
                if ~isempty(obj.client)
                    clear obj.client;
                end
            end

            % UI終了処理
            try
                if obj.view_waitbar && ishandle(obj.waitbarHandle)
                    waitbar(1, obj.waitbarHandle, 'All experiments finished.');
                    pause(1);
                    close(obj.waitbarHandle);
                end
            catch
            end
        end

        %% === DataQueue更新処理 ===
        function updateProgress(obj, val)
            obj.sendBuffered(val);
            obj.progressCount = obj.progressCount + 1;

            if obj.view_waitbar && ishandle(obj.waitbarHandle)
                p = obj.progressCount / obj.numExperiments;
                elapsed = toc(obj.tStart);
                hh = floor(elapsed/3600);
                mm = floor(mod(elapsed, 3600) / 60);
                ss = mod(elapsed, 60);
                waitbar(p, obj.waitbarHandle, ...
                    sprintf('Progress: %6.2f%% (%d/%d) | Time: %02d:%02d:%05.2f', ...
                    100*p, obj.progressCount, obj.numExperiments, hh, mm, ss));
            end
        end

        %% === バッファ送信 ===
        function sendBuffered(obj, val)
            if isempty(obj.buffer)
                obj.buffer = {};
            end
            if isempty(obj.lastSendTime)
                obj.lastSendTime = tic;
            end

            % FLUSH命令時
            if ischar(val) && strcmp(val, 'FLUSH')
                if ~isempty(obj.buffer) && obj.view_browser
                    msg = strjoin(cellfun(@jsonencode, obj.buffer, 'UniformOutput', false), newline);
                    obj.send(msg);
                end
                obj.buffer = {};
                return;
            end

            % 通常データ
            obj.buffer{end+1} = val;

            % バッファ条件で送信
            if length(obj.buffer) >= obj.bufferLimit || toc(obj.lastSendTime) >= obj.sendInterval
                if obj.view_browser
                    msg = strjoin(cellfun(@jsonencode, obj.buffer, 'UniformOutput', false), newline);
                    obj.send(msg);
                    obj.lastSendTime = tic;
                end
                obj.buffer = {};
            end
        end

        %% === TCP送信 ===
        function send(obj, msg)
            try
                if obj.view_browser && ~isempty(obj.client)
                    write(obj.client, [msg newline]);
                end
            catch ME
                fprintf("[Error:TCP] %s\n", ME.message);
            end
        end
    end
end

%% === wid取得 ===
% ヘルパー関数: 現在のワーカーIDを取得
function wid_str = getCurrentWorkerId()
    w = getCurrentWorker();
    if isempty(w)
        wid_str = 'unknown';
    elseif isa(w, 'parallel.cluster.MJSWorker') % Venus上
        wid_str = w.Host; % ワーカー名 (例: 'Venus1', 'Venus2')
    elseif isa(c, 'parallel.cluster.CJSWorker') % ローカル
        wid_str = string(w.ProcessId);
    else % 2022では到達しないはず．
        wid_str = w.Host; % MJSWorker以外に存在するプロパティ. workerの判別不可
    end
end
