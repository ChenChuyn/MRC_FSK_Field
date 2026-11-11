function [z0, z1, fsd] = fsk_frontend(r, params, D)
% FSK_FRONTEND  Same receiver front-end as estimate_channel/extract_payload_spectrum
% (branch BPF -> IQ down-conversion -> LPF), vectorised over antennas and
% decimated by D after the LPF (signal is band-limited to +-df there).
%   r  : Ns x Nr real passband signal (one column per antenna / frame)
%   z0, z1 : Nd x Nr complex baseband of branch f0=fc-df and f1=fc+df
fs = params.fs; fc = params.fc; df = params.df;
if isrow(r), r = r(:); end
t = (0:size(r,1)-1)' / fs;
[sb0, g0] = bsos(4, [fc-2*df, fc]/(fs/2), 'bandpass');  % SOS: order-8 narrow BPF in [b,a] is fragile
[sb1, g1] = bsos(4, [fc, fc+2*df]/(fs/2), 'bandpass');
[sl, gl]  = bsos(4, df/(fs/2), 'low');
z0 = branch(r, sb0, g0, fc-df);
z1 = branch(r, sb1, g1, fc+df);
fsd = fs / D;
    function z = branch(x, sb, gb, fb)
        xb = filtfilt(sb, gb, x);
        z  = filtfilt(sl, gl, xb .* exp(-1j*2*pi*fb*t));   % real/imag filtered separately = I + jQ
        z  = z(1:D:end, :);
    end
end

function [sos, g] = bsos(n, Wn, type)
[z, p, k] = butter(n, Wn, type); [sos, g] = zp2sos(z, p, k);
end
