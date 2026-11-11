% TX_REPEAT  MÁY PHÁT: phát cùng một khung BFSK params.K lần liên tiếp.
% Mỗi lần phát đóng vai một "anten" ở bên thu (SIMO giả lập bằng phân tập thời gian).
% Hai máy phải dùng CÙNG file create_params.m.
clear; clc;
params = create_params();
amp = 0.9;                                   % biên độ đầu ra (tránh méo/cắt đỉnh loa)

one = [tx_frame(params), zeros(1, round(params.gap*params.fs))];
sig = amp * repmat(one, 1, params.K);
fprintf('Phát %d lần x %.2f s = %.1f s | fs = %d Hz | f0 = %d Hz, f1 = %d Hz | %d bps\n', ...
    params.K, numel(one)/params.fs, numel(sig)/params.fs, params.fs, ...
    params.fc-params.df, params.fc+params.df, params.br);
audiowrite('tx_repeat.wav', sig, params.fs);  % có thể phát file này bằng phần mềm khác

disp('Đang phát...');
playblocking(audioplayer(sig, params.fs));
disp('Đã phát xong.');
