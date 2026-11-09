# Kiểm thử trực tiếp Web tối ưu — 09/11/2026

Nhánh `codex/staff-phase-one`, baseline 5084af0 và gói tối ưu trong commit chứa
báo cáo này. Chạy Flutter Web release mới tại http://127.0.0.1:7359 với
FIREBASE_EMULATORS=true; project demo-men-hair-booking, Auth 9099, Firestore
8080, Functions 5001. Kiểm thử trực tiếp bằng hai tab trình duyệt trong ứng dụng,
giao diện hẹp và rộng. Không lấy widget/HTTP thay bằng chứng UI.

Đã kiểm tra PID đang giữ cổng rồi thay đúng Web server, không restart/reset
Emulator; Flutter xác nhận build 51,8s và served 7359 trước khi reload tab.
Functions Emulator đã nạp các export từ source mới. Không mở bản production,
deploy, bật billing/API, tạo staging hoặc ghi Firebase thật; không sửa lịch 02/11.

## 1. Kết quả thao tác Web và số request thật

Đếm `stage=received` theo tên callable trong log Functions của demo tương tác,
không tính OPTIONS. Mốc UTC được ghi cùng counter trước/sau từng thao tác.
Không có tác vụ kiểm thử khác trên cổng demo trong khoảng đo đứng yên.

| Kiểm tra | Kết quả UI và backend |
| --- | --- |
| Tab chi nhánh → Nhân viên → Đánh giá/Chi nhánh → Nhân viên | Danh sách thợ vẫn hiện đúng, không treo. listBookableStaff giữ 15→15 khi chuyển tab; không tải lại chỉ vì build/PageView đổi trang. |
| Làm mới danh sách ở chi tiết salon | Danh sách hiển thị lại, listBookableStaff tăng đúng 15→16. |
| Chọn qua lại giữa hai thợ ở bước đặt lịch | Nút Tiếp tục mở; listBookableStaff giữ 17→17. Làm mới tải một lần, tăng lên 18 và xóa lựa chọn cũ; chọn lại thợ tiếp tục được. |
| Đứng yên ở chọn thợ | Từ 08:33:34.878 đến 08:34:52.321 UTC (77,4s), listBookableStaff giữ 17, getAvailability giữ 20. Không có polling. |
| Đổi ngày 09 → 10 → 15/11 | getAvailability 21→22→23, một lần/ngày chọn. 09/11 không có ca, 10/11 có giờ phù hợp; 15/11 chỉ có ca chiều. |
| Đứng yên ở chọn giờ | Từ 08:35:50.075 đến 08:37:00.889 UTC (70,8s), getAvailability giữ 23; listBookableStaff giữ 18, gồm cả các route nằm sau. |
| Làm mới giờ trống | getAvailability 23→24, đúng một lần tải. Chọn giờ không khởi động lại polling. |
| Đặt lịch từ tab B | Tab A và B cùng chọn nhân viên demo, chi nhánh 1, Combo 10 bước 60 phút, 15/11/2026 14:00, thanh toán sau. Tab B hiện “Đặt lịch thành công”. |
| Tab A gửi lựa chọn cũ | Backend từ chối failed-precondition, UI hiện “Không thể lưu lịch hẹn / Không có nhân viên có ca phù hợp và đủ giờ trống.” Sau đóng hộp, nút gửi hoạt động lại, không kẹt trạng thái chờ. |
| Quay về chọn giờ sau từ chối | Tự tải lại theo sự kiện quay về; xóa giờ đã chọn. 14:00 và 14:30 chuyển sang không bấm được, 15:00 vẫn khả dụng. |
| Hủy lịch từ tab B | UI hiện “Đã hủy”, giá lịch giữ 150.000đ, không bị xóa lịch. |
| Tab A làm mới sau hủy | 14:00/14:30 xuất hiện lại dưới dạng nút, chọn 14:00 được; dữ liệu không bị cache ở trạng thái bận cũ. Cập nhật giữa hai tab cần làm mới chủ động, không tuyên bố live push. |

## 2. Đối chiếu transaction/dữ liệu và lỗi

- Tạo thành công: request `1794213526579000_66717788`, resolved 715ms,
  booking `2vOTrY52v4c1j4CYoQXZ`.
- Lựa chọn trùng: request khác `1794213554660000_114098355`, rejected 221ms;
  không có booking thứ hai từ lần gửi này. Đây là chặn xung đột thật, không chỉ
  replay cùng requestId và không phải nút client tự chặn.
- Hủy: request `1794213616581000_23276451`, resolved 580ms. Đọc Emulator đối
  chiếu booking cancelled và cả hai slot released. Booking voucher cũ S9B2… vẫn
  cancelled, giữ nguyên. Tại giờ kiểm tra không có lịch cùng giờ còn hiệu lực.
- Console cả hai tab không có error mới trong khoảng test (từ 08:31:27 UTC).
  Không phát hiện lỗi mới cần sửa ngoài gói tối ưu đã có; không tăng timeout.

Bằng chứng ảnh/log/counter/dữ liệu đối chiếu ở `.dart_tool/optimized-web-*`,
không commit ảnh/log/dữ liệu Emulator. Tab B được đóng sau kiểm thử; tab A để
lại giờ 14:00 đã mở lại cho xem trước, Web server tiếp tục chạy.

## 3. Kiểm tra tự động và giới hạn

Trên cùng mã ứng viên: Emulator 43/43 (gồm quyền, trùng xuyên chi nhánh, bốn
tổ hợp A/B, cạnh tranh booking/ca/IPN, đo query và bảo toàn legacy), Flutter
22/22, analyze sạch, build Web Emulator đạt. Kết quả trước khi kiểm thử UI này
được giữ vì không sửa runtime/test sau đó; không lặp lại chỉ để tăng số lượt.

Chưa thử native Chrome/Android, Firebase cloud/index READY, fractional CPU/cold
start hay hóa đơn thật. Phương án triển khai tối thiểu và phần chưa tối ưu lịch
hẹn legacy ở [FIREBASE_THESIS_MINIMAL_PLAN.md](FIREBASE_THESIS_MINIMAL_PLAN.md).
Không merge main/deploy tự động; commit/push chỉ đóng gói source/config/tests/docs.
