# Kiểm tra đổi A/B ngày 01 và 10/12/2026

Kiểm thử cục bộ ngày 09/11/2026, project `demo-men-hair-booking`.
Không deploy, ghi Firebase thật, commit hoặc push trong lần xử lý này.

## Xung đột hợp lệ

Cặp đã thử trực tiếp trên Web:

- Nhân viên demo: ca S ngày 01/12/2026, 07:00–15:00.
- Đồng nghiệp demo: ca C ngày 10/12/2026, 14:00–22:00.
- Cả hai ca tại 30Shine 345 Nguyễn Văn Linh (`salon_01`).

Đổi A/B chuyển người phụ trách, giữ ngày/giờ/chi nhánh của mỗi ca. Sau đổi,
Đồng nghiệp demo sẽ nhận ca S ngày 01/12, nhưng người này đã có OFF cả ngày
01/12 (00:00–24:00) tại cùng chi nhánh. Vì vậy backend từ chối là đúng.
Đây không phải hai ca ở hai ngày khác nhau tự bị coi là trùng nhau.

Thông báo backend hiện nêu nhân viên, ngày, hai khoảng giờ, OFF và tên đầy đủ
của từng chi nhánh. Web hiển thị lỗi đổi ca trong hộp thoại có nội dung cuộn
và nút Đóng; không tự biến mất sau vài giây. Trạng thái chờ kết thúc khi bị từ
chối. Thuật toán trùng giờ trên mọi chi nhánh, OFF, kiểm tra lịch khách cả bốn
tổ hợp và transaction/idempotency được giữ nguyên.

Web đã tái hiện hộp thoại mới. Đối chiếu dữ liệu sau từ chối: ca S
`OZaPNtcaf9qqGEAGDLbD` vẫn thuộc `local-employee`, revision 1; OFF
`r4jl6dxn0sGUKtsRYwN4` vẫn thuộc `local-peer`, revision 1.

## Cặp hợp lệ và kết quả sau tải lại Web

Không có lịch khách còn hiệu lực tại cả bốn tổ hợp người/ngày 03 và 10/12.
Không có ca khác tại các ô đích, kể cả khác chi nhánh.

| Ngày | Giờ | Trước đổi | Sau đổi |
| --- | --- | --- | --- |
| 03/12/2026 | 14:00–22:00 | Nhân viên demo | Đồng nghiệp demo |
| 10/12/2026 | 14:00–22:00 | Đồng nghiệp demo | Nhân viên demo |

Cả hai vẫn ở 30Shine 345 Nguyễn Văn Linh. Admin chọn hai ô, xác nhận đổi và
Web báo “Đã lưu bảng phân ca”. Sau tải lại toàn trang, mở lại tháng 12,
Web vẫn hiện đúng hai người/ngày như bảng trên, các ô cũ không còn ca đó.

Backend nhận request `1794196177969000_926020908`, transaction hoàn thành
trong 423 ms, trả hai ID ca hiện có. `bh1MUjcjU2OtQFBYezsw` chuyển sang
`local-peer`, revision 2 → 3; `y6seO2HXG4R0M9xjljOr` chuyển sang
`local-employee`, revision 1 → 2. Không tạo ca thay thế hoặc xóa dữ liệu.

## Kiểm tra mã

- Backend/Rules: 34/34 đạt trên Emulator kiểm thử riêng 8180/9199/5101.
  Bổ sung kiểm tra nội dung lỗi OFF và xung đột hai chi nhánh: nhân viên,
  ngày, giờ, tên hai chi nhánh; xác nhận hai ca không đổi khi bị từ chối.
- Flutter: 18/18 đạt; `flutter analyze --no-pub`: không có vấn đề.
- Node syntax và `git diff --check`: đạt.
- Lần chạy thử đầu thiếu Functions Emulator nên 2 ca HTTP lỗi kết nối;
  chạy lại đủ ba dịch vụ đã đạt 34/34, không bỏ qua kiểm thử nào.
- Bằng chứng giao diện là trình duyệt Web trong ứng dụng; chưa kiểm thử
  độc lập thêm bằng Chrome native hoặc điện thoại thật trong lần này.

Các thay đổi cũ trên nhánh `codex/staff-phase-one` được giữ nguyên. Lần này
chỉ sửa nội dung lỗi backend, cách hiển thị lỗi đổi ca, kiểm thử liên quan
và báo cáo này. Không thay Rules hoặc quyền truy cập.
