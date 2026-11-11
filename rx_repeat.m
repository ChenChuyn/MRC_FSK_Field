% RX_REPEAT  MÁY THU: ghi âm params.K lần phát của tx_repeat.m, cắt K khung theo sync,
% coi mỗi khung là một "anten", so sánh các bộ thu (ZF/LS x MRC/MMSE/EGC/SC) và vẽ đồ thị.
%   SRC = ''            -> ghi âm trực tiếp từ micro (mặc định)
%   SRC = 'rx_xxx.wav'  -> xử lý lại một bản ghi đã lưu
if ~exist('SRC', 'var'), SRC = ''; end
if ~exist('SHOW', 'var'), SHOW = true; end   % vẽ đồ thị
params = create_params(); fs = params.fs; N = params.N; K = params.K; D = 16;
pb = params.payload_bits; Lf = params.frame_length;
P  = numel(tx_frame(params)) + round(params.gap*fs);   % chu kỳ lặp (mẫu)

% ======================= 1. Thu tín hiệu
if isempty(SRC)
    T = K*P/fs + 8;                          % dư ~8 s để kịp bấm phát ở máy kia
    fprintf('Ghi âm %.1f s - hãy chạy tx_repeat.m ở máy phát NGAY BÂY GIỜ...\n', T);
    rec = audiorecorder(fs, 16, 1); recordblocking(rec, T);
    y = getaudiodata(rec);
    stamp = datestr(now, 'yyyymmdd_HHMMSS');
    audiowrite(['rx_' stamp '.wav'], y, fs);   % lưu bản ghi gốc (không chuẩn hoá -> giữ mức tín hiệu)
    fprintf('Đã lưu bản ghi: rx_%s.wav (biên độ đỉnh %.3f)\n', stamp, max(abs(y)));
    if max(abs(y)) > 0.99, warning('Tín hiệu bị cắt đỉnh -> giảm âm lượng loa/micro.'); end
else
    [y, fsr] = audioread(SRC); y = y(:,1);
    assert(fsr == fs, 'bản ghi có fs = %d, cần %d', fsr, fs);
    [~, stamp] = fileparts(SRC);
end

% ======================= 2. Đồng bộ: tìm K vị trí sync (tương quan sau BPF)
ns = numel(params.sync)*N; t = (0:ns-1)'/fs;
sync_sig = linecoding(params.sync, N, 0)'.*cos(2*pi*(params.fc-params.df)*t) + ...
           linecoding(params.sync, N, 1)'.*cos(2*pi*(params.fc+params.df)*t);
[bw, aw] = butter(4, [params.fc-2.5*params.df, params.fc+2.5*params.df]/(fs/2), 'bandpass');
c = abs(fftfilt(flipud(sync_sig), filtfilt(bw, aw, y)));
cplot = c; idx = []; c0 = max(c);
for k = 1:K
    [m, i] = max(c);
    if m < 0.3*c0, break; end                % đỉnh quá yếu -> không phải khung
    st = i - ns + 1;
    if st >= 1 && st + Lf - 1 <= numel(y), idx(end+1) = st; end %#ok<SAGROW>
    c(max(1, i-round(P/2)) : min(end, i+round(P/2))) = 0;
end
idx = sort(idx); Kf = numel(idx);
assert(Kf > 0, 'Không tìm thấy khung nào: kiểm tra âm lượng, khoảng cách, thời điểm bấm phát.');
fprintf('Tìm thấy %d/%d khung, bắt đầu tại (s): %s\n', Kf, K, mat2str(idx/fs, 4));
r = zeros(Lf, Kf);
for k = 1:Kf, r(:,k) = y(idx(k) : idx(k)+Lf-1); end

% ======================= 3. Eb/N0 từng khung (payload so với guard cuối, sau đuôi CIR)
yb = filtfilt(bw, aw, r);
i_pay = (numel(params.sync)+params.z+numel(params.preamble))*N + (1:numel(pb)*N);
i_g = Lf - params.z*N + round(0.05*fs) : Lf;
Pn = mean(yb(i_g,:).^2); Ps = max(mean(yb(i_pay,:).^2) - Pn, eps);
EbN0 = 10*log10((Ps/params.br) ./ (Pn/(5*params.df)));
fprintf('Eb/N0 ước lượng từng khung (dB): %s\n', mat2str(EbN0, 3));

% ======================= 4. So sánh các bộ thu
%  ce   : 'zf' = H = Y/X trên toàn lưới FFT (gốc) | 'ls' = LS đáp ứng xung giới hạn trễ (đề xuất)
%  comb : 'mrc' (gốc) | 'mrcw' (MRC có trọng số 1/sigma^2) | 'mmse' | 'egc' | 'sc'
%  phase: 'global' = 1 góc xoay chung (gốc) | 'track' = bám pha trượt (đề xuất)
cfg = {'zf','mrc','global'; 'zf','mmse','track'; 'ls','mrc','track'; 'ls','mrcw','track'; ...
       'ls','mmse','track'; 'ls','egc','track'; 'ls','sc','track'};
names = join(upper(cfg(:,1:2)), '_', 2)'; names{1} = 'ZF_MRC_goc';
[z0, z1] = fsk_frontend(r, params, D);
ber_single = zeros(Kf, size(cfg,1)); ber_comb = zeros(Kf, size(cfg,1));
for c = 1:size(cfg,1)
    o = cell2struct(cfg(c,:)', {'ce','comb','phase'});
    for k = 1:Kf
        q = fsk_rx(z0(:,k), z1(:,k), params, D, o);      ber_single(k,c) = mean(q.bits ~= pb);
        q = fsk_rx(z0(:,1:k), z1(:,1:k), params, D, o);  ber_comb(k,c)   = mean(q.bits ~= pb);
    end
end
fprintf('\nBER từng khung riêng lẻ (hàng = khung/anten):\n'); disp(array2table(ber_single, 'VariableNames', names));
fprintf('BER khi kết hợp k khung đầu (hàng = k):\n');       disp(array2table(ber_comb,   'VariableNames', names));

% bộ thu đề xuất (LS + MMSE + bám pha) cho giải mã văn bản và đồ thị
opt = struct('ce','ls','comb','mmse','phase','track');
one = cell(1, Kf);
for k = 1:Kf, one{k} = fsk_rx(z0(:,k), z1(:,k), params, D, opt); end
best = fsk_rx(z0, z1, params, D, opt);
tb = (0:numel(best.ph)-1)/params.br; pf = polyfit(tb, best.ph, 1);
fprintf('Lệch tần ước lượng: %.3f Hz (%.1f ppm)\n', pf(1)/(2*pi), pf(1)/(2*pi)/params.fc*1e6);
fprintf('BER bộ thu đề xuất (LS/MMSE, %d khung): %.2e\n', Kf, mean(best.bits ~= pb));
fprintf('Văn bản giải mã:\n%s\n', bits2text_pad(double(best.bits)));

save(['ket_qua_' stamp '.mat'], 'r', 'idx', 'EbN0', 'ber_single', 'ber_comb', 'cfg', 'names', 'params');

% ======================= 5. Đồ thị
if ~SHOW, return; end
% (a) bản ghi và tương quan sync
figure('Name', 'Ban ghi va dong bo', 'Color', 'w');
subplot(2,1,1); plot((0:numel(y)-1)/fs, y); grid on; xlabel('t (s)'); ylabel('biên độ');
title('Bản ghi micro'); xline(idx/fs, 'r--');
subplot(2,1,2); plot((0:numel(cplot)-1)/fs, cplot/c0); grid on; xlabel('t (s)');
ylabel('|tương quan|'); title('Tương quan với chuỗi sync (đỉnh = cuối sync)');

% (b) tín hiệu thu từng anten: dạng sóng + phổ
figure('Name', 'Tin hieu thu tung anten', 'Color', 'w');
tf = (0:Lf-1)/fs;
for k = 1:Kf
    subplot(Kf, 2, 2*k-1); plot(tf, yb(:,k)); grid on; xlim(tf([1 end]));
    ylabel(sprintf('Anten %d', k)); title(sprintf('Dạng sóng sau BPF, Eb/N0 \\approx %.1f dB', EbN0(k)));
    subplot(Kf, 2, 2*k); [pxx, f] = pwelch(r(:,k), 8192, [], [], fs);
    plot(f/1e3, 10*log10(pxx)); grid on; xlim([params.fc-3*params.df, params.fc+3*params.df]/1e3);
    xline([params.fc-params.df, params.fc+params.df]/1e3, 'r--'); title('Phổ (f_0, f_1 nét đứt)');
end
xlabel(subplot(Kf,2,2*Kf-1), 't (s)'); xlabel(subplot(Kf,2,2*Kf), 'f (kHz)');

% (c) chòm sao trước / sau xoay pha: từng anten + kết hợp
figure('Name', 'Chom sao truoc va sau xoay pha', 'Color', 'w');
rows = [one, {best}]; nr = numel(rows); col = pb(:) == 1;
for k = 1:nr
    q = rows{k}; s = q.raw / rms(q.raw); sr = q.sym / rms(q.sym);
    if k <= Kf, lab = sprintf('Anten %d', k); else, lab = sprintf('Kết hợp %d anten', Kf); end
    subplot(nr, 3, 3*k-2); cplt(s, col); title([lab ': trước xoay pha']);
    subplot(nr, 3, 3*k-1); cplt(sr, col);
    title(sprintf('sau xoay pha, BER = %.1e', mean(q.bits ~= pb)));
    subplot(nr, 3, 3*k); plot((0:numel(q.ph)-1)/params.br, q.ph); grid on;
    title('pha ước lượng \phi[m] (rad)');
end
xlabel(subplot(nr,3,3*nr), 't (s)');

function cplt(s, col)
plot(real(s(~col)), imag(s(~col)), '.', 'MarkerSize', 4); hold on;
plot(real(s(col)), imag(s(col)), '.', 'MarkerSize', 4); hold off;
axis equal; grid on; m = 1.1*max(abs(s)); axis([-m m -m m]); xline(0, 'k:');
end
