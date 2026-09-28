# Voucher và tích điểm

## Chức năng

- Chính sách tích lũy có thể thưởng theo số lần hoàn thành dịch vụ, theo giá trị từng đơn hoặc bật đồng thời cả hai.
- Màn `Thông báo & ưu đãi` hiển thị thông báo mã khuyến mãi, tiến độ tích điểm và danh sách voucher tích lũy cá nhân.
- Màn xác nhận đặt lịch cho phép nhập mã khuyến mãi hoặc chọn voucher tích lũy trước khi chọn thanh toán sau hoặc VNPAY.
- Khách có thể dùng đồng thời tối đa hai voucher tích lũy: một voucher theo số lần hoàn thành dịch vụ và một voucher theo giá trị đơn hàng. Hai mức giảm được cộng lại và tổng tiền không bao giờ nhỏ hơn 0đ.
- Voucher theo giá trị đơn hàng dùng mã hiển thị `CHITIEU`; dữ liệu cũ có mã dạng `DON...` cũng được hiển thị lại thành `CHITIEU`.
- Mã khuyến mãi nhập thủ công không dùng chung với voucher tích lũy.
- Admin có thể tạo, sửa, tạm dừng và xóa voucher dùng chung, bao gồm mức giảm và giá trị đơn tối thiểu.
- Voucher dùng chung có giới hạn tổng số khách; mỗi tài khoản chỉ được dùng một lần.
- Khi admin tạo voucher, hệ thống chỉ gửi thông báo chung kèm chi tiết mã; voucher không tự được cấp vào tài khoản người dùng.
- Voucher do admin tạo phải được khách nhập mã thủ công. Danh sách chọn voucher chỉ hiển thị voucher tích lũy cá nhân.
- Voucher chỉ bị trừ lượt khi khách thực sự dùng trong lúc đặt lịch.
- Admin có màn `Quản lý tích điểm` với hai mục độc lập; mỗi mục có công tắc, điều kiện và phần trăm giảm riêng.

## Dữ liệu Firestore

- `voucher_templates/{voucherId}`: voucher dùng chung do admin quản lý.
- `voucher_templates/{voucherId}/redemptions/{userId}`: ghi nhận khách đã dùng voucher để ngăn dùng lặp.
- `users/{userId}/vouchers/{voucherId}`: voucher cá nhân từ chương trình tích điểm.
- `app_settings/loyalty`: chính sách tích lũy hiện hành do admin cấu hình.
- Booking lưu thêm `originalPrice`, `discountAmount`, `totalPrice`, `voucher` (tương thích dữ liệu cũ), `vouchers` và `voucherIds`.

Voucher cá nhân được đánh dấu đã dùng trong cùng transaction tạo booking. Với voucher dùng chung, transaction đồng thời kiểm tra tồn lượt, tăng `usedCount` và tạo redemption theo người dùng, nên nhiều khách đặt cùng lúc cũng không thể vượt `usageLimit`. `totalPrice` sau giảm cũng là số tiền Cloudflare Worker gửi sang VNPAY.

## Cập nhật sau khi merge

```powershell
git pull origin main
firebase deploy --project men-hair-booking --only firestore:rules
flutter pub get
flutter analyze
flutter run -d chrome
```

Không cần deploy lại Cloudflare Worker vì Worker hiện đã đọc `booking.totalPrice`; trường này đã là giá cuối sau voucher.
