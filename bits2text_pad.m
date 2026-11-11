function txt = bits2text_pad(bits)
%BITS2TEXT_PAD  Chuyển vector bit 1xN về chuỗi ASCII
% Tự chèn bit 0 ở cuối nếu số bit không chia hết cho 8

    bits = bits(:).';   % đảm bảo row vector

    r = mod(length(bits),8);
    if r ~= 0
        % padding 0 ở cuối
        bits = [bits zeros(1, 8-r)];
    end

    % reshape về từng byte
    b = reshape(bits, 8, []).';

    % bit -> số
    ascii = bi2de(b, 'left-msb');

    % số -> ký tự
    txt = char(ascii).';
end
