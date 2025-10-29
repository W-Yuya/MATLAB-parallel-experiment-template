% src/klnmf.m
function [W, H, cost] = klnmf(X,W,H,max_iter)
% KLNMFでXを低ランク近似するWとHを求める関数
% 
% [input]
% X : double (I, J) isbenonnegative - 観測行列
% W : double (I, K) isbenonnegative - 基底行列
% H : double (K, J) isbenonnegative - 係数行列
% [output]
% W : double (I, K) - 推定した基底行列
% H : double (K, J) - 推定した係数行列
% cost : double (1, 1) - 最終的な目的関数値

[W, H] = local_normalization(W,H);

for i = 1:max_iter
    W = max(W.*(X./(W*H)*H.')./(sum(H.',1)), eps);
    H = max(H.*(W.'*(X./(W*H)))./(sum(W.',2)), eps);

    [W,H] = local_normalization(W,H);
end
cost = local_calcCost(X,W*H);
end

function [W,H] = local_normalization(W,H)
% スケール調整関数
C = sum(W,1);
W = W./C;
H = (C.').*H;
end

function cost = local_calcCost(X,WH)
% 目的関数値産出関数
cost = sum((X.*log(X./WH) - (X-WH)), "all");
end