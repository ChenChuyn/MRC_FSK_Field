function out = fsk_rx(z0, z1, params, D, opts)
% FSK_RX  Header-aided FDE BFSK receiver with multi-antenna combining.
%   z0, z1 : baseband branches from fsk_frontend (Nd x Nr), sample 1 = header (sync) start
%   opts.ce    : 'zf'  - original: H = HP ./ XP over the whole FFT grid
%                'ls'  - proposed: time-domain LS of a delay-limited CIR (taps -Kpre..Kpost)
%   opts.comb  : 'mrc' | 'egc' | 'sc' | 'mmse'  -> see combine_all_subcarriers.m
%   opts.phase : 'global' - original: one rotation = mean angle of samples with Re>0
%                'track'  - proposed: sliding squared-phase tracking + preamble sign fix
%   opts.tmax  : CIR length assumed by 'ls' (s), default 20 ms
%   opts.W     : tracking window in symbols, default 32
% out.bits (payload, row), out.sym (phase-corrected payload symbols), out.sigma2
if ~isfield(opts,'tmax'), opts.tmax = 20e-3; end
if ~isfield(opts,'W'),    opts.W = 32; end
persistent Pcache
if isempty(Pcache), Pcache = containers.Map; end
ref = fsk_ref(params, D);
Nd = ref.Nd; Lh = ref.Lh; Lz = ref.Lz; Lp = ref.Lp; Ld = ref.Ld; L = ref.L;
Nb = Ld / Nd;  npre = numel(params.preamble);
w0 = ref.w0;                              % data window start (preamble start)
Kpre = ref.Kpre; Kpost = ceil(opts.tmax * ref.fsd);

X = cell(1,2); sig2 = zeros(2, size(z0,2));
Z = {z0, z1};
for b = 1:2
    z  = Z{b};
    hp = z(1:Lh+Lz, :);
    yd = z(w0 : w0+L-1, :);
    YD = fft(yd, L, 1);
    % noise from the header guard, after the CIR tail has died out
    g = z(Lh+Kpost+Kpre+1 : Lh+Lz-Kpre, :);
    sig2(b,:) = mean(abs(g).^2, 1);
    switch opts.ce
        case 'zf'
            XP = fft(ref.xh{b}, L);
            H = fft(hp, L, 1) ./ (XP + 1e-6) + 1e-6;   % as estimate_channel.m
        case {'zfreg', 'zfwin'}                        % reviewer baselines
            XP = fft(ref.xh{b}, L); HP = fft(hp, L, 1);
            if strcmp(opts.ce, 'zfreg')                % per-bin Wiener (Tikhonov) regularisation
                sH = max(mean(abs(HP).^2, 1) - (Lh+Lz)*sig2(b,:), eps) / mean(abs(XP).^2);
                H = HP .* conj(XP) ./ (abs(XP).^2 + (Lh+Lz)*sig2(b,:) ./ sH);
            else                                       % DFT-based: ZF on usable bins only, then keep CIR-window taps
                use = abs(XP) > 0.05 * max(abs(XP));   % out-of-band / near-null bins are ill-conditioned
                Hz = zeros(size(HP)); Hz(use, :) = HP(use, :) ./ XP(use);
                h = ifft(Hz, [], 1);
                keep = false(L, 1); keep(mod(-Kpre:Kpost, L) + 1) = true;
                h(~keep, :) = 0; H = fft(h, [], 1);
            end
        case 'ls'
            key = sprintf('%d_%d_%d_%d', b, Kpre, Kpost, Lh);
            if ~isKey(Pcache, key)
                Pcache(key) = pinv(conv_matrix(ref.xh{b}, Kpre, Kpost, Lh + Kpost));
            end
            h = Pcache(key) * hp(1:Lh+Kpost, :);      % LS CIR, (Kpre+Kpost+1) x Nr
            hz = zeros(L, size(z,2));
            hz(mod(-Kpre:Kpost, L) + 1, :) = h;       % negative delays wrap (zero-phase LPF)
            H = fft(hz, L, 1);
    end
    XR = combine_all_subcarriers(H, YD, opts.comb, sig2(b,:), ref.Sx);
    xr = ifft(XR(:));
    X{b} = xr(1:Lp + Ld);
end
xd = X{2} - X{1};                       % bit 1 -> f1 branch (as rx.m)
s  = mean(reshape(xd, Nd, []), 1);      % integrate-and-dump per symbol (preamble + payload)
pay = npre + (1:Nb);
switch opts.phase
    case 'global'                       % rx.m / paper Step 9 on payload samples
        xp = xd(Lp+1:end);
        q = xp(real(xp) > 0);
        if isempty(q), pha = mean(angle(xp)); else, pha = mean(angle(q)); end
        ph = pha * ones(size(s));
    case 'track'
        ph = unwrap(angle(movsum(s.^2, opts.W))) / 2;     % BPSK: squaring removes data
        pre = 2*params.preamble - 1;
        if sum(real(s(1:npre) .* exp(-1j*ph(1:npre))) .* pre) < 0, ph = ph + pi; end
end
sr = s .* exp(-1j*ph);
out.bits = real(sr(pay)) >= 0;
out.sym = sr(pay);
out.raw = s(pay);  out.ph = ph(pay);
out.sigma2 = sig2;
end

function A = conv_matrix(x, Kpre, Kpost, M)
% rows n=1..M, cols k=-Kpre..Kpost : A(n,k) = x(n-k)
x = x(:); Nx = numel(x);
k = -Kpre:Kpost; n = (1:M)';
idx = n - k;
A = zeros(M, numel(k));
ok = idx >= 1 & idx <= Nx;
A(ok) = x(idx(ok));
end
