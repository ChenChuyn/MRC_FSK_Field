# MRC-FSK thực nghiệm: thu phát BFSK âm thanh giữa 2 máy tính với kết hợp phân tập

Chương trình thu phát BFSK qua loa và micro, kèm bộ thu cải tiến:

- ước lượng kênh **LS theo đáp ứng xung giới hạn trễ**;
- kết hợp **MRC / MRC có trọng số nhiễu / MMSE / EGC / SC** trên từng bin tần số;
- **bám pha trượt** để bù lệch tần giữa hai card âm thanh.

Thay vì dùng nhiều micro (SIMO thật), máy phát phát **cùng một khung K lần**. Máy thu ghi âm một lần, cắt ra K khung và coi mỗi khung là một "anten". Đây là **phân tập thời gian** (SIMO giả lập).

## 1. Yêu cầu

- MATLAB R2021a trở lên, có **Signal Processing Toolbox** (`butter`, `filtfilt`, `fftfilt`, `pwelch`, `hilbert`) và **Communications Toolbox** (`de2bi`, `bi2de`).
- Hai máy tính, mỗi máy chép **toàn bộ thư mục này** (bắt buộc dùng cùng `create_params.m`).
- Máy phát có loa, máy thu có micro, cả hai chạy được **fs = 96 kHz**. Tín hiệu nằm trong dải 16,6–18,2 kHz, nên loa và micro phải đáp ứng được tần số này.

## 2. Các file

| File | Vai trò |
|---|---|
| `create_params.m` | Toàn bộ tham số: fc = 17,4 kHz, Δf = 400 Hz (f0 = 17,0 kHz, f1 = 17,8 kHz), 300 bps, fs = 96 kHz, guard z, **K (số lần phát)**, **gap (khoảng lặng)** |
| `tx_frame.m` | Tạo một khung: `[preamble, sync 247 bit, guard, preamble 64 bit, payload, guard]` |
| `tx_repeat.m` | **Chạy ở máy phát**: phát khung K lần, đồng thời lưu `tx_repeat.wav` |
| `rx_repeat.m` | **Chạy ở máy thu**: ghi âm, đồng bộ, cắt K khung, so sánh các bộ thu, giải mã văn bản, vẽ đồ thị |
| `fsk_frontend.m` | Lọc thông dải từng tone, hạ tần IQ, lọc thông thấp, giảm mẫu D = 16 |
| `fsk_ref.m` | Tín hiệu tham chiếu của sync ở tốc độ đã giảm mẫu |
| `fsk_rx.m` | Bộ thu: ước lượng kênh (ZF / LS), kết hợp, tích phân ký hiệu, xoay pha |
| `combine_all_subcarriers.m` | Các luật kết hợp `mrc`, `mrcw`, `mmse`, `egc`, `sc` |
| `test_repeat.m` | Kiểm tra offline không cần loa/micro (kênh đa đường + lệch tần + nhiễu giả lập) |
| `text2bits.m`, `bits2text_pad.m`, `linecoding.m` | Chuyển văn bản ↔ bit, tạo dạng sóng bit |

## 3. Kiểm tra trước khi đo (khuyến nghị)

Mở MATLAB trong thư mục này và chạy:

```matlab
test_repeat
```

Nếu in ra `test_repeat: OK` và hiện 3 cửa sổ đồ thị thì code chạy đúng trên máy đó.

## 4. Các bước thực nghiệm

1. **Bố trí:** đặt loa máy phát và micro máy thu cách nhau 1–5 m. Có thể đặt trong bể nước nếu có loa/hydrophone. Tắt các chế độ xử lý âm thanh của Windows (Noise suppression, Echo cancellation, Audio enhancements) và đặt định dạng thiết bị là **96000 Hz** (Sound settings → Device properties → Advanced).
2. **Chỉnh âm lượng:** loa khoảng 30–60 %, micro sao cho đỉnh bản ghi < 0,9 (chương trình sẽ cảnh báo nếu tín hiệu bị cắt đỉnh). Để kết quả có ý nghĩa cho bài báo, nên tạo vài điều kiện Eb/N0 khác nhau (thay đổi âm lượng hoặc khoảng cách) thay vì chỉ đo ở mức rất sạch.
3. **Máy thu:** chạy `rx_repeat`. Chương trình in ra thời gian ghi âm, khoảng K × 21,4 s + 8 s với tham số mặc định.
4. **Máy phát:** trong vòng vài giây, chạy `tx_repeat`.
5. Chờ ghi âm xong. Máy thu tự xử lý và in ra:
   - số khung tìm được và vị trí của chúng;
   - **Eb/N0 ước lượng của từng khung**;
   - **bảng BER từng khung riêng lẻ** và **bảng BER khi kết hợp k = 1…K khung**, cho 7 bộ thu:

     | Cột | Ước lượng kênh | Kết hợp | Xoay pha |
     |---|---|---|---|
     | `ZF_MRC_goc` | ZF (gốc) | MRC | một góc chung (gốc) |
     | `ZF_MMSE` | ZF | MMSE | bám pha |
     | `LS_MRC` | LS | MRC | bám pha |
     | `LS_MRCW` | LS | MRC trọng số 1/σ² | bám pha |
     | `LS_MMSE` | LS | MMSE | bám pha |
     | `LS_EGC` | LS | EGC | bám pha |
     | `LS_SC` | LS | chọn lọc (SC) | bám pha |

   - lệch tần ước lượng (Hz, ppm) và văn bản giải mã bằng bộ thu đề xuất LS/MMSE.
6. Kết quả được lưu tự động:
   - `rx_<ngày_giờ>.wav`: bản ghi gốc;
   - `ket_qua_<ngày_giờ>.mat`: các khung đã cắt `r`, `EbN0`, `ber_single`, `ber_comb`.

Để xử lý lại một bản ghi cũ mà không cần đo lại:

```matlab
SRC = 'rx_20261111_153000.wav'; rx_repeat
```

## 5. Đồ thị của chương trình thu

1. **Bản ghi và đồng bộ:** dạng sóng micro, kèm vị trí các khung tìm được (nét đứt đỏ), và tương quan với chuỗi sync.
2. **Tín hiệu thu từng anten:** dạng sóng sau lọc thông dải (kèm Eb/N0) và phổ quanh f0, f1 của mỗi khung/anten.
3. **Chòm sao trước và sau xoay pha:** mỗi hàng là một anten, hàng cuối là kết hợp K anten.
   - Cột 1: ký hiệu `s[m]` trước xoay pha. Lệch tần làm chòm sao bị quay thành vòng tròn.
   - Cột 2: sau xoay pha bằng bám pha. Hai cụm ±1 tách rõ; màu cho biết bit phát là 0 hay 1.
   - Cột 3: pha ước lượng φ[m] theo thời gian. Độ dốc của đường này tương ứng với lệch tần.

## 6. Thay đổi tham số

Sửa trong `create_params.m` và **chép cùng file đó sang cả hai máy**:

- `params.K`: số lần phát, tức số "anten". Mặc định 4.
- `params.gap`: khoảng lặng giữa hai lần phát. Mặc định 1 s.
- `params.text`: nội dung phát. Văn bản càng dài thì khung càng dài.
- `params.z`: độ dài guard (bit). Phải lớn hơn trải trễ kênh. Mặc định 250 bit = 0,83 s.

## 7. Xử lý lỗi thường gặp

| Hiện tượng | Nguyên nhân / cách xử lý |
|---|---|
| `Không tìm thấy khung nào` | Bấm phát quá muộn, âm lượng quá nhỏ, hoặc micro lọc mất dải 17 kHz. Kiểm tra phổ bằng đồ thị 2. |
| Tìm được ít hơn K khung | Khung cuối bị cắt do ghi âm kết thúc trước. Hãy bấm phát sớm hơn hoặc tăng phần dư `+ 8` trong `rx_repeat.m`. |
| `bản ghi có fs = 48000` | Card âm thanh không hỗ trợ 96 kHz. Cần chỉnh định dạng thiết bị trong Windows. |
| Cảnh báo cắt đỉnh, BER cao ở mọi bộ thu | Giảm âm lượng loa hoặc độ nhạy micro. |
| `ZF_MRC_goc` có BER ≈ 0,5 nhưng các cột `LS_*` ≈ 0 | Đây là kết quả bình thường: bộ thu gốc không bù được lệch tần giữa hai máy và ước lượng ZF bị điều kiện kém. |

## 8. Ghi chú khi đưa kết quả vào bài báo

- Các khung cách nhau khoảng 21 s, nên đây là **phân tập thời gian** chứ không phải nhiều micro đặt khác vị trí. Cần ghi rõ như vậy trong bài báo.
- Nên ghi lại Eb/N0 của từng lần đo (chương trình đã in ra). Nếu Eb/N0 rất cao, BER bằng 0 của mọi bộ thu LS sẽ không phân biệt được các luật kết hợp.

Tác giả thuật toán: Nguyễn Quốc Khương. Cài đặt: Nguyễn Hồng Phúc.
