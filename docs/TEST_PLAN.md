# Kế hoạch kiểm thử nghiệm thu

Ngày lập: 01/10/2026

## Quy ước

- **P0:** bắt buộc đạt trước khi demo.
- **P1:** nên đạt trước khi đóng gói.
- **P2:** kiểm tra bổ sung.
- Ghi kết quả thực tế vào cột **Kết quả**: `Đạt`, `Không đạt` hoặc `Chưa chạy`.

## Tài khoản và xác minh email

| ID | Ưu tiên | Kịch bản | Kết quả mong đợi | Kết quả |
|---|---|---|---|---|
| AUTH-01 | P0 | Đăng ký Gmail mới với dữ liệu hợp lệ | Tạo hồ sơ, gửi email và quay về đăng nhập | Chưa chạy |
| AUTH-02 | P0 | Đăng nhập trước khi bấm liên kết xác minh | Chỉ mở màn hình xác minh, không vào trang chủ | Chưa chạy |
| AUTH-03 | P0 | Bấm liên kết Gmail rồi chọn “Tôi đã xác minh” | Vào trang chủ thành công | Chưa chạy |
| AUTH-04 | P1 | Gửi lại email nhiều lần liên tục | Nút bị khóa 60 giây và không gửi dồn | Chưa chạy |
| AUTH-05 | P0 | Đăng ký trùng email | Hiển thị thông báo email đã tồn tại | Chưa chạy |
| AUTH-06 | P1 | Nhập sai email, mật khẩu ngắn, số điện thoại sai | Form chặn và giải thích đúng | Chưa chạy |
| AUTH-07 | P0 | Quên mật khẩu | Gmail nhận liên kết đặt lại mật khẩu | Chưa chạy |
| AUTH-08 | P0 | Đăng nhập tài khoản admin | Mở đúng dashboard admin | Chưa chạy |
| AUTH-09 | P1 | Mất mạng lúc đăng nhập/xác minh | Hiển thị lỗi, không treo màn hình | Chưa chạy |

## Đặt lịch và khung giờ

| ID | Ưu tiên | Kịch bản | Kết quả mong đợi | Kết quả |
|---|---|---|---|---|
| BOOK-01 | P0 | Chọn chi nhánh, nhiều dịch vụ, thợ và giờ trống | Tổng giá/thời lượng đúng, tạo một booking | Chưa chạy |
| BOOK-02 | P0 | Chọn “Thợ bất kỳ” | Hệ thống gán một thợ còn trống | Chưa chạy |
| BOOK-03 | P0 | Hai tài khoản đặt cùng thợ/cùng giờ | Chỉ một booking thành công | Chưa chạy |
| BOOK-04 | P0 | Thanh toán sau | Booking được xác nhận ngay và admin thấy “Thanh toán sau” | Chưa chạy |
| BOOK-05 | P0 | Chỉnh sửa dịch vụ của lịch chưa trả tiền | Cập nhật giá, thời lượng và slot đúng | Chưa chạy |
| BOOK-06 | P1 | Thêm dịch vụ làm vượt quá giờ trống | Từ chối và yêu cầu chọn lịch khác | Chưa chạy |
| BOOK-07 | P0 | Hủy lịch chưa thanh toán | Booking chuyển hủy và giải phóng slot | Chưa chạy |
| BOOK-08 | P1 | Sửa lịch đã dùng voucher hoặc đã thanh toán | Bị chặn với thông báo rõ ràng | Chưa chạy |
| BOOK-09 | P1 | Đặt lịch ở thời điểm quá khứ/ngoài giờ mở cửa | Không cho đặt | Chưa chạy |
| BOOK-10 | P1 | Khách khác đọc/sửa booking không thuộc mình | Firestore từ chối | Chưa chạy |

## Thanh toán VNPAY Sandbox

| ID | Ưu tiên | Kịch bản | Kết quả mong đợi | Kết quả |
|---|---|---|---|---|
| PAY-01 | P0 | Thanh toán Sandbox thành công | IPN đặt `paid`, booking `confirmed`, tạo thông báo | Chưa chạy |
| PAY-02 | P0 | Hủy tại cổng VNPAY | Không đánh dấu đã thanh toán | Chưa chạy |
| PAY-03 | P0 | IPN sai chữ ký | Worker trả mã 97, Firestore không đổi | Chưa chạy |
| PAY-04 | P0 | IPN sai số tiền | Worker trả mã 04, Firestore không đổi | Chưa chạy |
| PAY-05 | P1 | VNPAY gửi lại cùng IPN | Không ghi nhận thanh toán hai lần | Chưa chạy |
| PAY-06 | P0 | Tài khoản khác yêu cầu thanh toán booking | Worker trả 403 | Chưa chạy |
| PAY-07 | P1 | Bấm thanh toán nhiều lần nhanh | Không tạo trạng thái đơn mâu thuẫn | Chưa chạy |
| PAY-08 | P1 | Worker mất kết nối Firestore | Báo lỗi an toàn, không hiện thanh toán giả | Chưa chạy |

## Voucher và tích lũy

| ID | Ưu tiên | Kịch bản | Kết quả mong đợi | Kết quả |
|---|---|---|---|---|
| VOU-01 | P0 | Nhập mã hợp lệ, đủ giá trị tối thiểu | Giảm đúng phần trăm | Chưa chạy |
| VOU-02 | P0 | Mã hết hạn/hết lượt/tạm dừng | Không áp dụng được | Chưa chạy |
| VOU-03 | P0 | Người dùng thứ tư dùng voucher giới hạn 3 lượt | Bị từ chối | Chưa chạy |
| VOU-04 | P0 | Dùng lại mã khuyến mãi đã sử dụng | Bị từ chối | Chưa chạy |
| VOU-05 | P0 | Chọn hai voucher tích lũy khác loại | Áp dụng cả hai theo quy tắc hiện tại | Chưa chạy |
| VOU-06 | P1 | Chọn mã khuyến mãi chung cùng voucher tích lũy | Bị chặn | Chưa chạy |
| VOU-07 | P0 | Admin hoàn thành lịch đạt mốc số lần | Tạo một voucher và một thông báo | Chưa chạy |
| VOU-08 | P0 | Admin hoàn thành đơn đạt mức chi tiêu | Tạo voucher CHITIEU đúng phần trăm | Chưa chạy |
| VOU-09 | P1 | Gọi trao thưởng lần hai cho cùng booking | Không tạo voucher trùng | Chưa chạy |

## Admin và phân quyền

| ID | Ưu tiên | Kịch bản | Kết quả mong đợi | Kết quả |
|---|---|---|---|---|
| ADM-01 | P0 | User thường mở màn hình/chức năng admin | Không thể ghi dữ liệu quản trị | Chưa chạy |
| ADM-02 | P0 | Admin thêm/sửa/xóa dịch vụ | Khách thấy danh mục cập nhật | Chưa chạy |
| ADM-03 | P0 | Admin quản lý nhân viên/mẫu tóc/hotline | Dữ liệu cập nhật đúng chi nhánh | Chưa chạy |
| ADM-04 | P0 | Admin xem lịch theo ba chi nhánh | Lịch lọc và sắp xếp đúng | Chưa chạy |
| ADM-05 | P0 | Admin hoàn thành lịch | User nhận thông báo và có thể đánh giá | Chưa chạy |
| ADM-06 | P1 | Admin hủy lịch | Giải phóng slot và user nhận thông báo | Chưa chạy |
| ADM-07 | P1 | Admin gửi thông báo khuyến mãi | User nhìn thấy nội dung | Chưa chạy |
| ADM-08 | P1 | User và admin gửi chat | Hai phía nhận đúng hội thoại | Chưa chạy |

## Giao diện và phát hành

| ID | Ưu tiên | Kịch bản | Kết quả mong đợi | Kết quả |
|---|---|---|---|---|
| UI-01 | P0 | Chrome web ngang | Không tràn, không màn đen | Chưa chạy |
| UI-02 | P0 | Điện thoại Android dọc | Nội dung cuộn/chuyển trang đúng | Chưa chạy |
| UI-03 | P1 | Danh sách không có dữ liệu | Có empty state, không lỗi | Chưa chạy |
| UI-04 | P1 | Ảnh mạng lỗi hoặc tải chậm | Có placeholder, không vỡ bố cục | Chưa chạy |
| REL-01 | P0 | `flutter analyze` | Không có issue | Chưa chạy |
| REL-02 | P0 | `flutter test` và `npm test` | Tất cả test đạt | Chưa chạy |
| REL-03 | P0 | Build APK release | Tạo APK và cài được trên Android | Chưa chạy |
| REL-04 | P1 | Build Web release | Build thành công và chạy đúng route | Chưa chạy |

## Bằng chứng nghiệm thu

Với mỗi nhóm P0, lưu:

1. Ảnh màn hình đầu vào.
2. Ảnh kết quả mong đợi.
3. Log Terminal nếu là test/build.
4. UID hoặc booking ID mẫu (che thông tin nhạy cảm).
5. Ghi lỗi phát hiện, commit sửa và kết quả kiểm tra lại.
