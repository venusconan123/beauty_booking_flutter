# Thanh toán khi hoàn thành

Theo lựa chọn ngày 13/11/2026, xác nhận Hoàn thành cũng xác nhận đã nhận đủ tiền.
Nhân viên không cần chờ admin ghi thu riêng đối với lịch thanh toán tại quầy.

- Backend cập nhật trạng thái `completed` và `payment.status: paid` cùng giao dịch.
- Số tiền là `totalPrice` đã lưu sau ưu đãi; không lấy số tiền do client gửi lên.
- Ghi biên nhận `salon_<bookingId>`, người thao tác và thời gian máy chủ.
  `method: completion`, `source: booking_completion` mô tả cách ghi nhận;
  không tự nhận là tiền mặt hay chuyển khoản khi chưa có thông tin này.
- Giữ nguyên giao dịch online đã thanh toán, không thu thêm.
- Lỗi tiền không hợp lệ hoặc online chưa thanh toán sẽ hủy toàn bộ giao dịch hoàn thành.
- Retry hoặc nhiều thao tác đồng thời không tạo thêm khoản thu, thưởng hay biên nhận.
- Thống kê nhân viên/khách/admin nhận thay đổi qua dữ liệu Firestore đang theo dõi.

Áp dụng cho lần chuyển sang Hoàn thành từ bản này. Không tự đổi trạng thái thanh toán
của lịch cũ đã hoàn thành: admin vẫn có thể ghi nhận thanh toán cho các lịch đó sau
khi đối chiếu đã thu tiền. Không chạy di chuyển hoặc sửa dữ liệu khách thật khi kiểm thử.

Kiểm tra 13/11/2026: 97 bài backend/Rules/REST và 11 bài Flutter đều đạt;
Flutter analyzer không báo lỗi. Worker đã triển khai phiên bản
`0b33d16d-0980-477a-9431-e2efb8e5373e`.
