# Voucher và tích điểm

## Chức năng

- Mỗi 10 lịch hẹn được admin đánh dấu `completed`, khách hàng nhận một voucher giảm 25%.
- Màn `Thông báo & ưu đãi` hiển thị tiến độ tích điểm và danh sách voucher.
- Màn xác nhận đặt lịch cho phép chọn voucher đủ điều kiện trước khi chọn thanh toán sau hoặc VNPAY.
- Admin có thể tạo, sửa, tạm dừng và xóa voucher dùng chung, bao gồm mức giảm và giá trị đơn tối thiểu.

## Dữ liệu Firestore

- `voucher_templates/{voucherId}`: voucher dùng chung do admin quản lý.
- `users/{userId}/vouchers/{voucherId}`: voucher cá nhân từ chương trình tích điểm.
- Booking lưu thêm `originalPrice`, `discountAmount`, `totalPrice` và `voucher`.

Voucher cá nhân được đánh dấu đã dùng trong cùng transaction tạo booking để tránh dùng lặp. `totalPrice` sau giảm cũng là số tiền Cloudflare Worker gửi sang VNPAY.

## Cập nhật sau khi merge

```powershell
git pull origin main
firebase deploy --project men-hair-booking --only firestore:rules
flutter pub get
flutter analyze
flutter run -d chrome
```

Không cần deploy lại Cloudflare Worker vì Worker hiện đã đọc `booking.totalPrice`; trường này đã là giá cuối sau voucher.
