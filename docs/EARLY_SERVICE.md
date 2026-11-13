# Bắt đầu phục vụ sớm

Nhân viên có thể bắt đầu lịch đã xác nhận trước giờ đặt trong cùng ngày Việt Nam,
sau khi xác nhận khách đã đến và đồng ý được phục vụ sớm.

Backend kiểm tra lại trong giao dịch:
- Tài khoản nhân viên được xác minh, đang hoạt động và được giao lịch này.
- Không còn lịch khác đang phục vụ, kể cả lịch quá giờ dự kiến nhưng chưa hoàn thành.
- Giờ hiện tại và toàn bộ thời lượng dịch vụ (làm tròn theo ô 30 phút) nằm trong ca tại đúng chi nhánh.
- Khoảng phục vụ thực tế không trùng lịch khác còn hiệu lực, kể cả ở chi nhánh khác.
- Lịch đã hủy hoặc hoàn thành không còn chặn giờ.

Giữ nguyên `appointmentAt`, giờ đã đặt, giá và thanh toán. Ghi riêng
`serviceStartedAt`, `serviceExpectedEndAt`, `startedEarly`; giao diện hiển thị giờ
bắt đầu thực tế. Khi đang phục vụ, cả giờ đã đặt và khoảng thực tế được bảo vệ
khỏi đặt trùng. Hoàn thành giải phóng các khoảng này và tự ghi nhận thanh toán
đủ tiền đối với lịch thanh toán tại quầy (xem `COMPLETION_PAYMENT.md`).

Kiểm thử: `functions/test/scheduling.emulator.test.cjs`,
`cloudflare_worker/test/firestore-rest.emulator.test.js`,
`test/staff_workflow_widgets_test.dart`. Dữ liệu kiểm thử ghi vào Firebase giả lập,
không thay đổi lịch khách thật. Cloudflare dùng cùng handler với bộ kiểm thử.

Sau khi cập nhật source, khởi động lại app Flutter để nhận giao diện mới.

Đã kiểm tra ngày 13/11/2026: 45 bài scheduling/Firebase Rules, 4 bài REST
adapter và 8 bài Flutter widget đều đạt; Flutter analyzer không báo lỗi.
Worker online đã triển khai phiên bản `f7f483de-e854-4d19-ba2e-2dea7ca640c6`.
