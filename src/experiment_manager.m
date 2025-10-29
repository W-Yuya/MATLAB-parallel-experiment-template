% src/experiment_manager.m
function experiment_manager(experiment_config)

% === 実験条件の取得 ===
output_path = experiment_config.output_path;
I = experiment_config.obs_row;
J = experiment_config.obs_col;
obs_basis = experiment_config.obs_basis;
X = experiment_config.obs_matrix;
module_list = experiment_config.module_list;
max_iter = experiment_config.max_iter;
% スイープパラメータ
basis_list = experiment_config.basis_list;
seed_list = experiment_config.seed_list;

% === 出力ファイルの作成  ===
% 深いディレクトリ構造は対応してないので注意
[output_dir, ~] = fileparts(output_path);
if ~isfolder(output_dir); mkdir(output_dir); end
if exist(output_path, 'file') == 2
    % すでにある場合は何もしない
else % ファイルがなければ空のtableを作成
    writetable(table(), output_path);
end

% === ndgridで全ての組み合わせを生成・条件数を取得 ===
[K_grid, seed_grid] = ndgrid(basis_list, seed_list);
num_experiment = numel(K_grid);
result_cell = cell(num_experiment,1);

% === parpoolの事前起動 ===
delete(gcp('nocreate'));
parpool('VenusFullCluster');
addAttachedFiles(gcp, module_list); % module_list = "src/klnmf.m"
updateAttachedFiles(gcp);

% === ProgressManagerの初期化 ===
% parallel_config.mのpath（main.mからの相対位置）
pm_config_path = "parallel";
% "main.mのpath
pm_experiment_root = "C:\Users\kitalab-admin\Desktop\sample_exp";
% pm = ProgressManager(num_experiment,pm_config_path, pm_experiment_root);
% ↓ディレクトリ構造が同じなら引数不要
pm = ProgressManager(num_experiment);
% pmの初期化時点でタイマー開始

% === 並列実験本体 ===
fprintf("[experiment_manager]:Parallel proceeding...\n");
parfor expID = 1:num_experiment
    % 実験処理
    K = K_grid(expID);
    seed = seed_grid(expID);

    rng(seed); % seed固定
    W_init = rand(I, K);
    H_init = rand(K, J);

    [~, ~, cost] = klnmf(X, W_init, H_init, max_iter);

    % 結果の格納
    result_cell{expID} = {expID, I, J, obs_basis, max_iter, K, seed, cost};

    % === 進捗更新 ===
    pm.sendProgress(expID);
end
pm.flush(); % バッファのクリア
% === 結果の書き込み ===
fprintf("[experiment_manager]:Output results...\n");
result_table  = cell2table(result_cell);
existingTable = readtable(output_path);
result_table  = [existingTable; result_table];
writetable(result_table, output_path);

% === 終了通知 ===
pm.sendFinish();
end