function bits = text2bits(txt)
%TEXT2BITS  Chuyển chuỗi ký tự sang vector bit (1xN)
%   txt  : char array hoặc string
%   bits : vector 1xN gồm các bit 0/1 (MSB trước)

    if isstring(txt)
        txt = char(txt);
    end

    % Chuyển ký tự sang mã ASCII
    ascii = uint8(txt);

    % Mỗi ký tự -> 8 bit, MSB trước
    b = de2bi(ascii, 8, 'left-msb');

    % Ghép thành vector 1 chiều
    bits = reshape(b.', 1, []);
end
