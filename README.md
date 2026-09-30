# Men Hair Booking

Ứng dụng Flutter đặt lịch dịch vụ tóc nam, xây dựng cho đồ án tốt nghiệp. Ứng dụng hỗ trợ giao diện điện thoại và web ngang, sử dụng Firebase Authentication/Firestore/Storage và tích hợp VNPAY Sandbox qua Cloudflare Worker.

## Chức năng chính

### Khách hàng

- Đăng ký, đăng nhập, quên mật khẩu và cập nhật hồ sơ.
- Xem chi nhánh trên danh sách/bản đồ, dịch vụ, nhân viên và mẫu tóc.
- Đặt lịch theo chi nhánh, dịch vụ, thợ và khung giờ; chống trùng lịch.
- Chọn thanh toán sau hoặc thanh toán ngay bằng VNPAY Sandbox.
- Sử dụng voucher khuyến mãi và voucher tích lũy.
- Theo dõi lịch hẹn, thông báo, đánh giá và chat với admin.

### Quản trị viên

- Dashboard số lịch, doanh thu, thanh toán, tỷ lệ hủy và số lịch theo chi nhánh.
- Quản lý lịch hẹn, dịch vụ, nhân viên, mẫu tóc, hotline và báo cáo.
- Quản lý voucher, chính sách tích lũy, thông báo và tin nhắn hỗ trợ.

## Công nghệ

- Flutter/Dart, Material 3
- Firebase Authentication
- Cloud Firestore và Firebase Storage
- Cloudflare Workers
- VNPAY Sandbox

## Chạy dự án

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Triển khai cấu hình Firebase

```powershell
firebase deploy --project men-hair-booking --only firestore:rules,storage
```

Worker VNPAY:

```powershell
cd cloudflare_worker
npm test
npx wrangler deploy
```

Không đưa Terminal ID, Secret Key hoặc Firebase service account vào Git. Thiết lập các giá trị bí mật bằng `wrangler secret` theo [VNPAY_SETUP.md](VNPAY_SETUP.md).

Firestore là cơ sở dữ liệu NoSQL dạng document. Danh sách collection, quan hệ logic và luồng nghiệp vụ được mô tả trong [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

> Thanh toán trong đồ án sử dụng môi trường VNPAY Sandbox, không phát sinh giao dịch tiền thật.
