# Kiểm thử trực tiếp Web với Emulator — 09/11/2026

Phạm vi: bản Flutter Web release trên http://127.0.0.1:7359, có
`FIREBASE_EMULATORS=true`, project `demo-men-hair-booking`. Auth 9099,
Firestore 8080, Functions 5001. Thao tác bằng giao diện trình duyệt trong ứng
dụng; không lấy VM/HTTP thay bằng chứng UI. Giữ dữ liệu Emulator đã có, chỉ
thêm fixture kiểm thử cục bộ; không sửa lịch thật 02/11, không deploy hoặc
ghi Firebase thật. Nhánh đích `codex/staff-phase-one`, không merge main.

## Kết quả từng luồng

| Luồng | Kết quả trực tiếp |
| --- | --- |
| Admin phân ca, đóng ghi | Chọn nhân viên demo ngày 14/11, HC 09:00–17:00. Backend từ chối; hộp “Không thể lưu lịch làm” hiện thông báo bảo trì. Đóng hộp: nút phân ca hoạt động, ô vẫn chưa xếp. |
| Admin phân ca, mở ghi | Thử lại lưu HC thành công, ô hiện HC và hết chờ. Tạo thêm ca C 14:00–22:00 cho đồng nghiệp ngày 15/11 thành công. |
| Admin đổi A/B | Chọn hai ca trên, xem trước và xác nhận. Nhân viên demo nhận C ngày 15/11, đồng nghiệp nhận HC ngày 14/11. Kết quả vẫn đúng khi đăng nhập nhân viên, tải lại trang và mở tháng lần nữa. |
| Khách đặt có voucher, đóng ghi | Chọn chi nhánh 1, Combo 10 bước 60 phút, nhân viên demo, 15/11 lúc 14:00. WEBDEMO10 giảm 150.000đ còn 135.000đ. Gửi thanh toán sau: hộp “Không thể lưu lịch hẹn” hiện bảo trì, nút được mở lại khi đóng hộp. |
| Khách thử lại, mở ghi | Cùng nội dung và cùng requestId được gửi lại, Web hiện “Đặt lịch thành công”. Chỉ một booking được tạo, voucher usedCount = 1. |
| Nhân viên xem lịch | Đăng nhập được đưa thẳng vào Lịch hẹn, thấy đúng Combo 10 bước ngày 15/11 lúc 14:00. Lịch làm hiển thị bản đổi ca và “Lịch cùng chi nhánh • Chỉ xem”, không có thao tác phân/đổi ca. Sau reload vẫn đúng. |
| Khách hủy voucher, đóng ghi | Hộp “Không thể hủy lịch hẹn” hiện bảo trì; lịch vẫn xác nhận, đóng hộp và cuộn lại thấy nút Hủy hoạt động. |
| Khách hủy, mở ghi | Thử lại thành công, Web hiện “Đã hủy”, giá 135.000đ vẫn được giữ. Emulator đối chiếu status cancelled, hai slot released, voucher usedCount vẫn 1; không có booking thứ hai. |

Booking demo kiểm tra: `S9B2zYkGVB0YzAyimn38`. Mã yêu cầu tạo (bị chặn rồi
thử lại): `1794210045100000_462287425`; Functions ghi rejected 419ms, sau mở
gate resolved 297ms. Đổi A/B resolved 731ms. Các log và dữ liệu đối chiếu ở
`.dart_tool/`, không đưa vào Git. Công tắc demo được trả về mở booking/roster/
staff, vẫn đóng paymentCreation. Bản Web để lại chạy cho xem trước.

## Lỗi phát hiện và sửa

- Phân ca chỉ hiện SnackBar ngắn cho lỗi đóng ghi: chuyển lỗi backend xác định
  sang hộp thoại đọc được, xóa yêu cầu chờ và kết thúc busy trước khi hiện lỗi.
- Xác nhận đặt lịch chưa bắt riêng SchedulingRejectedException: hiện nội dung
  backend trong hộp lỗi, mở lại nút gửi, vẫn giữ requestId để thử lại.
- Hủy lịch chỉ bắt FirebaseException: bổ sung lỗi backend và lỗi khác, khóa nút
  trong lúc gửi, bảo đảm mở lại trong finally. Lần thử Web đầu phát hiện context
  của hàng bị hủy khi stream dựng lại khiến mất hộp lỗi; sửa dùng context của
  State màn hình. Đã dựng lại Web và thử lại cả hủy đóng/mở ghi thành công.
- Console có một lỗi từ lần hủy trước sửa lúc 07:41:45 UTC; không thấy lỗi mới
  sau tải bản sửa và thử lại. Không coi log cũ là lỗi của bản sửa cuối.

## Kiểm tra tự động và giới hạn

Flutter analyze không có vấn đề; Flutter 20/20. Bộ Emulator riêng 40 ca bao
gồm quyền, gate, voucher, callback lặp/song song và callback tranh chấp hủy;
Worker 9 ca. Kết quả cuối được kiểm tra lại trước commit. Cổng kiểm thử riêng
8180/9199/5101 không reset dữ liệu demo tương tác 8080/9099/5001.

Chưa kiểm thử trình duyệt Chrome native, Android, thiết bị thật, HTTPS/staging,
IAM runtime/App Check hoặc IPN ngân hàng thật. Không mở VNPAY online trong
luồng UI này. Trùng ca xuyên chi nhánh và chặn đổi khi có lịch khách được giữ
nguyên, có kiểm thử backend; không tái hiện thêm các cặp xung đột qua UI trong
lượt này. Các điểm chặn triển khai, backup/restore và dữ liệu cần duyệt vẫn ở
PRODUCTION_PREP_LOCAL_REVIEW.md và production-preview; chưa phê duyệt apply.

## Mở demo

Mở http://127.0.0.1:7359. Đăng xuất nếu cần rồi chọn menu Demo ở màn hình
đăng nhập. Admin demo / Nhân viên demo / Khách hàng demo dùng Auth Emulator.
Các email lần lượt là local-admin@example.test, local-staff@example.test,
local-customer@example.test; mật khẩu chỉ dành cho demo: Local-demo-123!.
Không dùng các tài khoản này với Firebase thật.
