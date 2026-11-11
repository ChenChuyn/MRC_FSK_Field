function XR0 = combine_all_subcarriers(H0, YD0, method, sigma2, Sx)
% COMBINE_ALL_SUBCARRIERS - Kết hợp phân tập trên từng subcarrier (bin FFT)
%
%   XR0 = combine_all_subcarriers(H0, YD0)                 % MRC như bản gốc
%   XR0 = combine_all_subcarriers(H0, YD0, method, sigma2, Sx)
%
% Inputs:
%   H0, YD0 : cell {1 x nFrames} các vector độ dài L, hoặc ma trận L x nFrames
%   method  : 'mrc'  (mặc định, bản gốc)  X = sum(H'.*Y) / (sum|H|^2 + 1e-6)
%             'mrcw' MRC weighted by 1/sigma2 of each branch
%             'egc'  equal gain           X = sum(e^{-j angle H}.*Y) / sum|H|
%             'sc'   selection             X = Y_k / H_k,  k = argmax_i |H_i|^2/sigma2_i
%             'mmse' MMSE                   X = sum(H'.*Y/s2) / (sum|H|^2/s2 + L/Sx)
%   sigma2  : 1 x nFrames phương sai nhiễu mỗi nhánh/frame (mặc định 1)
%   Sx      : L x 1 công suất kỳ vọng E|X(k)|^2 của khối dữ liệu (bắt buộc với 'mmse')
%
% Output:
%   XR0 : vector phức (1 x L) đã kết hợp (cùng định dạng hàng như bản gốc)

    if nargin < 3, method = 'mrc'; end
    H = to_mat(H0); Y = to_mat(YD0);
    if isempty(H) || ~isequal(size(H), size(Y))
        error('H0 và YD0 phải cùng số phần tử, cùng độ dài và không rỗng.');
    end
    [L, nF] = size(H);
    if nargin < 4 || isempty(sigma2), sigma2 = ones(1, nF); end
    s2 = reshape(sigma2, 1, nF);

    switch lower(method)
        case 'mrc'
            XR0 = sum(conj(H) .* Y, 2) ./ (sum(abs(H).^2, 2) + 1e-6);
        case 'mrcw'                    % MRC with per-branch noise weights (unequal noise levels)
            XR0 = sum(conj(H) .* Y ./ s2, 2) ./ (sum(abs(H).^2 ./ s2, 2) + 1e-6 / mean(s2));
        case 'egc'
            XR0 = sum(exp(-1j*angle(H)) .* Y, 2) ./ (sum(abs(H), 2) + 1e-6);
        case 'sc'
            [~, k] = max(abs(H).^2 ./ s2, [], 2);
            idx = sub2ind([L nF], (1:L)', k);
            XR0 = Y(idx) ./ (H(idx) + 1e-6);
        case 'mmse'
            if nargin < 5, error('MMSE cần Sx (công suất tín hiệu theo bin).'); end
            XR0 = sum(conj(H) .* Y ./ s2, 2) ./ (sum(abs(H).^2 ./ s2, 2) + L ./ Sx(:));
        otherwise
            error('method không hợp lệ: %s', method);
    end
    XR0 = XR0.';
end

function M = to_mat(C)
% cell các vector -> ma trận L x nFrames
if iscell(C)
    C = C(~cellfun(@isempty, C));
    M = cell2mat(cellfun(@(v) v(:), C, 'UniformOutput', false));
else
    M = C;
end
end
