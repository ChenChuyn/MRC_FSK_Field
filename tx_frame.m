function frame_sig = tx_frame(params)
% TX_FRAME  Passband BFSK frame [preamble sync ze preamble payload ze] (row, fs = params.fs).
% The leading preamble is cut off at the receiver (frame starts at sync), so the rest
% is exactly params.frame_bits = [sync ze preamble payload ze].
N = params.N; ze = zeros(1, params.z*N);
s = cell(1, 2);
for b = 0:1
    s{b+1} = [linecoding(params.preamble, N, b) linecoding(params.sync, N, b) ze ...
              linecoding(params.preamble, N, b) linecoding(params.payload_bits, N, b) ze];
end
assert(numel(s{1}) - numel(params.preamble)*N == params.frame_length);
t = (0:numel(s{1})-1) / params.fs;
frame_sig = cos(2*pi*(params.fc-params.df)*t) .* s{1} + cos(2*pi*(params.fc+params.df)*t) .* s{2};
end
