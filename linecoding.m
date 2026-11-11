function baseband_sig = linecoding(bits, N, high_bit)
    % bits: chuỗi đầu vào (ví dụ: [0 1 0 1])
    % N: số mẫu trên mỗi bit (ví dụ: 9)
    % high_bit: giá trị bit mà bạn muốn là mức cao (ví dụ: 1 hoặc 0)

    % Kiểm tra nếu bit hiện tại bằng với high_bit thì gán mức 1, ngược lại gán mức 0
    % Logic này giúp bạn linh hoạt quy định mức cao cho bất kỳ bit nào
    logic_bits = (bits == high_bit);
    
    % Mở rộng chuỗi tín hiệu
    baseband_sig = repmat(logic_bits(:), 1, N)';
    baseband_sig = baseband_sig(:)';
end