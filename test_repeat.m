% TEST_REPEAT  Kiểm tra offline toàn bộ chương trình (không cần loa/micro):
% K lần phát -> kênh đa đường khác nhau mỗi lần + lệch tần -0.15 Hz + nhiễu -> wav -> rx_repeat.
clear; clc;
params = create_params(); fs = params.fs; K = params.K; rng(1);
one = [tx_frame(params), zeros(1, round(params.gap*fs))];
y = zeros(round(2.3*fs) + K*numel(one), 1);
for k = 1:K                                   % kênh 5 tia ngẫu nhiên, trễ 0..6 ms
    h = zeros(round(6e-3*fs), 1); h(1 + randi(numel(h)-1, 4, 1)) = 0.5*randn(4, 1); h(1) = 1;
    s = filter(h, 1, one(:));
    s = real(hilbert(s) .* exp(-2j*pi*0.15*(0:numel(s)-1)'/fs));
    i0 = round(2.3*fs) + (k-1)*numel(one);
    y(i0 + (1:numel(s))) = y(i0 + (1:numel(s))) + s;
end
y = y + 3*std(y)*randn(size(y));             % nhiễu băng rộng -> Eb/N0 ~ 12-15 dB mỗi khung
SRC = fullfile(tempdir, 'test_repeat.wav'); audiowrite(SRC, 0.5*y/max(abs(y)), fs);
rx_repeat;
assert(ber_comb(end, strcmp(names, 'LS_MMSE')) < 1e-3, 'bộ thu đề xuất không giải mã được tín hiệu thử');
delete(['ket_qua_' stamp '.mat']);
disp('test_repeat: OK');
