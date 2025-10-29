% ワークスペースのクリア
clc; close all; clear;

% pathの追加
addpath("./src/", "./parallel/")

fprintf("[main]:Preprocessing...\n");
% 実験条件の設定
output_path = "./results/result.xlsx";
obs_row = 1000;
obs_col = 1000; % 観測行列のサイズ
obs_basis = 50; % 観測行列の基底数
module_list = "src/klnmf.m"; % parpoolで使用するファイル
max_iter = 500;

basis_list = 10:1:50; % 近似に用いる基底数
seed_list = 1:10; % 乱数シード

% 実験データの前処理
% 実際はデータセットに対する前処理など
x1 = rand(obs_row, obs_basis);
x2 = rand(obs_basis, obs_col);
X = x1 * x2;
obs_matrix = X./max(X, [], "all");

% 実験条件の格納と実験関数の呼び出し
experiment_config = struct( ...
    'output_path', output_path, ...
    'obs_row', obs_row, ...
    'obs_col', obs_col, ...
    'obs_basis', obs_basis, ...
    'obs_matrix', obs_matrix, ...
    'module_list', module_list, ...
    'max_iter', max_iter, ...
    'basis_list', basis_list, ...
    'seed_list', seed_list);

fprintf("[main]:Experiment running...\n");
experiment_manager(experiment_config)

fprintf("[main]:Experiment finished.\n");