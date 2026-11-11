function params = create_params()
% CREATE_PARAMS Khởi tạo struct chứa toàn bộ thông số hệ thống
%   params = create_params() trả về struct với các trường:
%       .text, .fc, .df, .fs, .br, .z, .N, .preamble, .sync,
%       .payload_bits, .ze_bits, .frame_bits, .frame_length

    % Văn bản cần truyền
    params.text = 'trong moi truong nghien cuu khoa hoc hien dai viec ung dung cac thuat toan vao xu ly tin hieu so la dieu vo cung can thiet de toi uu hoa hieu suat truyen thong tin tren cac kenh truyen nhieu nhu am thanh duoi nuoc viec phan tich pho va su dung cac chuoi dong bo nhu m sequence se giup xac dinh chinh xac thoi diem bat dau khung.trong moi truong nghien cuu khoa hoc hien dai viec ung dung cac thuat toan vao xu ly tin hieu so la dieu vo cung can thiet de toi uu hoa hieu suat truyen thong tin tren cac kenh truyen nhieu nhu am thanh duoi nuoc viec phan tich pho va su dung cac chuoi dong bo nhu m sequence se giup xac dinh chinh xac thoi diem bat dau khung.';
    
    % Thông số điều chế
    params.fc = 17400;      % tần số sóng mang (Hz)
    params.df = 400;        % độ dịch tần số FSK (Hz)
    params.fs = 96000;      % tần số lấy mẫu (Hz)
    params.br = 300;        % tốc độ bit (bps)
    params.z = 250;         % số bit zero chèn vào frame
    params.K = 4;           % số lần phát lặp = số "anten" ở bên thu (SIMO giả lập)
    params.gap = 1.0;       % khoảng lặng giữa 2 lần phát (s), lớn hơn trải trễ kênh
    
    % Số mẫu trên mỗi bit
    params.N = round(params.fs / params.br);
    
    % Preamble 64 bit (dạng nhị phân)
    params.preamble = [1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 ...
                       1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 ...
                       1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0 ...
                       1 0 1 0 1 0 1 0 1 0 1 0 1 0 1 0];
    
    % Sync 247 bit
    params.sync = [1 1 1 1 1 1 1 1 0 1 1 1 0 0 0 1 0 0 1 1 1 0 1 0 0 1 0 1 1 0 0 1 ...
                   1 1 1 1 0 1 0 0 0 0 1 0 0 1 0 0 0 1 1 0 1 0 1 1 1 0 1 1 1 1 0 0 ...
                   1 0 0 0 0 1 0 1 1 1 0 1 1 0 1 0 1 0 0 0 1 1 1 0 0 0 0 1 1 1 0 1 ...
                   1 1 0 0 0 1 0 1 0 0 1 1 1 1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 1 0 1 1 ...
                   1 0 1 0 1 1 0 1 0 0 0 1 1 1 0 0 0 0 1 1 0 1 1 0 1 1 0 0 0 1 0 1 ...
                   0 0 1 1 1 1 1 1 0 1 1 0 0 1 0 0 0 0 1 1 1 0 1 1 0 1 0 0 0 1 1 0 ...
                   1 0 1 0 1 1 0 0 1 1 1 0 0 1 0 0 1 0 1 1 0 0 0 0 1 1 0 1 0 1 0 1 ...
                   0 1 0 0 1 1 0 1 1 1 0 0 0 1 1 0 1 1 0 0 1 1 0];
    
    % Chuyển văn bản thành chuỗi bit
    params.payload_bits = text2bits(params.text);
    
    % Bit zero chèn (số bit = z)
    params.ze_bits = zeros(1, params.z);
    
    % Ghép toàn bộ frame (ở dạng bit)
    params.frame_bits = [params.sync, params.ze_bits, params.preamble, ...
                         params.payload_bits, params.ze_bits];
    
    % Chiều dài frame tính theo số mẫu
    params.frame_length = length(params.frame_bits) * params.N;
end