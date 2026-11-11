function ref = fsk_ref(params, D)
% FSK_REF  Known baseband references at the decimated rate (cached).
%   xh{1}, xh{2} : header (sync) of branch 0 / 1 after the same LPF as the receiver
%   Sx           : E|X(k)|^2 of the OOK data block on the L-point grid (for MMSE)
persistent cache key
k = sprintf('%g_%g_%g_%g_%d_%d', params.fs, params.df, params.br, params.z, numel(params.payload_bits), D);
if isequal(k, key), ref = cache; return; end
fs = params.fs; N = params.N; Nd = N / D;
assert(Nd == round(Nd), 'N must be a multiple of D');
[zz, pp, kk] = butter(4, params.df/(fs/2), 'low'); [sl, gl] = zp2sos(zz, pp, kk);
lp = @(x) filtfilt(sl, gl, x(:));
nz = 4 * N;                                    % let the LPF tails settle before decimating
for b = 0:1
    x = [linecoding(params.sync, N, b), zeros(1, nz)];
    x = 0.5 * lp(x);                           % cos*cos -> 1/2 after LPF
    ref.xh{b+1} = x(1:D:end);
end
p = 0.5 * lp([zeros(1,nz), ones(1,N), zeros(1,nz)]);
p = p(1:D:end);
ref.Nd = Nd; ref.fsd = fs / D;
ref.Lh = numel(params.sync) * Nd;
ref.Lz = params.z * Nd;
ref.Lp = numel(params.preamble) * Nd;
ref.Ld = numel(params.payload_bits) * Nd;
ref.L  = ref.Lp + ref.Ld + ref.Lz;             % window: preamble+payload+guard (>= Lh+Lz)
assert(ref.L >= ref.Lh + ref.Lz);
ref.w0 = ref.Lh + ref.Lz + 1;
ref.Kpre = ceil(3e-3 * ref.fsd);               % zero-phase LPF pre-cursor
nb = (ref.Lp + ref.Ld) / Nd;                   % symbols in the window, a ~ {0,1}: var 1/4
ref.Sx = nb * 0.25 * abs(fft(p, ref.L)).^2 + 1e-12;
cache = ref; key = k;
end

