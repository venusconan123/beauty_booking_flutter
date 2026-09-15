# VNPAY Sandbox + Cloudflare Worker

## 1. Các bí mật bắt buộc

Worker cần bốn Cloudflare Secrets:

- `VNP_TMN_CODE`
- `VNP_HASH_SECRET`
- `FIREBASE_WEB_API_KEY`
- `FIREBASE_SERVICE_ACCOUNT_JSON`

Không đưa các giá trị này vào Git hoặc mã Flutter.

## 2. Lấy Firebase Service Account

Trong Firebase Console, mở **Project settings > Service accounts > Generate new private key** và tải file JSON về máy. Khóa này có quyền truy cập dữ liệu dự án: chỉ dùng cho dự án thử nghiệm, không chia sẻ và không commit. Nếu bị lộ, thu hồi khóa ngay trong Google Cloud Console. `FIREBASE_WEB_API_KEY` là giá trị `apiKey` trong `lib/firebase_options.dart`.

## 3. Cài và triển khai Worker

Chạy trong PowerShell tại thư mục dự án:

```powershell
cd .\cloudflare_worker
npm install
npx wrangler login

npx wrangler secret put VNP_TMN_CODE
npx wrangler secret put VNP_HASH_SECRET
npx wrangler secret put FIREBASE_WEB_API_KEY
Get-Content -Raw "C:\duong-dan\service-account.json" |
  npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON

npx wrangler deploy
```

Khi Wrangler hỏi giá trị của ba secret đầu tiên, dán giá trị tương ứng. Lệnh `Get-Content` gửi nguyên file JSON lên Cloudflare mà không đưa khóa vào mã nguồn.

Sau khi hoàn tất, xóa file service account khỏi thư mục Downloads hoặc cất ở nơi an toàn.

## 4. Cấu hình VNPAY

- Return URL: `https://men-hair-booking-vnpay.venusconan23.workers.dev/vnpay-return`
- IPN URL: `https://men-hair-booking-vnpay.venusconan23.workers.dev/vnpay-ipn`
- Payment URL Sandbox: `https://sandbox.vnpayment.vn/paymentv2/vpcpay.html`

Lưu ý: VNPAY cần biết IPN URL của merchant. Hãy đăng ký/cấu hình IPN URL này trong tài khoản Sandbox hoặc liên hệ kênh hỗ trợ VNPAY được nêu trong email cấp mã. Return URL chỉ hiển thị thông tin; ứng dụng chỉ đánh dấu `paid` khi IPN hợp lệ được Worker xử lý.

## 5. Triển khai Flutter và Firestore Rules

```powershell
cd C:\Users\tranl\beauty_booking_flutter
flutter pub get
firebase deploy --project men-hair-booking --only firestore:rules
dart format .\lib
flutter analyze
flutter run -d chrome
```

Chỉ lịch có trạng thái `confirmed` mới xuất hiện nút thanh toán. Sau khi VNPAY gửi IPN có chữ ký hợp lệ và đúng số tiền, Worker mới cập nhật `payment.status` thành `paid`.

Đây là tích hợp **cổng VNPAY Sandbox thật**, không phải giao dịch tiền thật. Nếu Return URL báo đang chờ, hãy kiểm tra IPN URL đã đăng ký và Logs trong Cloudflare. Các lịch đã thanh toán rồi bị admin hủy cần quy trình hoàn tiền riêng; bản đồ án chưa có hoàn tiền.
