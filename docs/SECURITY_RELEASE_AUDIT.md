# Báo cáo sẵn sàng phát hành

Ngày rà soát: 01/10/2026

## Phạm vi

- Firebase Authentication và xác minh email
- Firestore/Storage Rules
- Đặt lịch, khóa khung giờ và voucher
- Cloudflare Worker/VNPAY Sandbox
- Kiểm thử tự động hiện có
- Cấu hình phát hành Android và Web

## Kết luận

Ứng dụng đã đủ chức năng cho đồ án và kiến trúc VNPAY đúng hướng: Secret Key nằm ở Worker, IPN được kiểm tra chữ ký, merchant, số tiền, booking và trạng thái đơn trước khi cập nhật Firestore.

Trước khi đóng gói bản cuối cần hoàn thành các mục P0/P1 dưới đây.

## Phát hiện ưu tiên

| ID | Mức | Phát hiện | Ảnh hưởng | Hướng xử lý |
|---|---|---|---|---|
| SEC-01 | P0 | Người dùng được phép cập nhật toàn bộ document `users/{uid}` | Có thể tự đổi `requiresEmailVerification` hoặc các trường hệ thống bằng client tùy chỉnh | Chỉ cho sửa `name`, `phone`, `updatedAt`; chỉ cho đặt `emailVerified=true` khi token Firebase đã xác minh email |
| SEC-02 | P0 | Rule tạo `bookings` tin giá, dịch vụ, thời lượng và chi nhánh do client gửi | Client tùy chỉnh có thể tạo lịch thanh toán sau với giá/dữ liệu không hợp lệ | Kiểm tra giá dịch vụ từ collection `services` hoặc chuyển tạo booking quan trọng sang backend |
| SEC-03 | P0 | Mọi người dùng đăng nhập có thể tạo document `booking_slots` nếu ghi UID của chính họ | Có thể tạo slot giả để chiếm lịch của nhân viên | Ràng buộc slot phải trỏ tới booking được tạo cùng giao dịch và khớp user/salon/barber |
| SEC-04 | P1 | Worker xác thực Firebase ID token nhưng chưa kiểm tra `emailVerified` | Client bỏ qua UI vẫn có thể gọi API thanh toán | Trả thêm trạng thái xác minh từ Firebase lookup và từ chối tài khoản bắt buộc xác minh nhưng chưa xác minh |
| SEC-05 | P1 | Chưa có test tự động cho Firestore/Storage Rules | Thay đổi rule dễ làm hỏng phân quyền | Thêm Firebase Emulator test cho user, admin, booking, slot và voucher |
| PAY-01 | P1 | Admin có thể hủy lịch đã thanh toán nhưng chưa có quy trình hoàn tiền | Trạng thái nghiệp vụ có thể không khớp tiền đã thu | Hiển thị cảnh báo và trạng thái `refund_required`, hoặc chặn hủy nếu chưa xử lý hoàn tiền |
| QA-01 | P1 | Flutter hiện chỉ có 2 file unit test | Các luồng auth, booking và voucher chưa được bảo vệ khi sửa code | Bổ sung unit/widget/integration test theo TEST_PLAN |
| REL-01 | P1 | Android release đang ký bằng debug key | Không phù hợp bản phát hành chính thức | Tạo keystore riêng và cấu hình `key.properties` ngoài Git |
| REL-02 | P2 | Tên, mô tả và icon còn dấu vết Flutter mặc định | Bản demo thiếu hoàn thiện | Đổi Android label, Web title/description, icon và splash |
| REL-03 | P2 | Firebase mới cấu hình Android và Web | Không thể chạy bản iOS | Chỉ cần xử lý nếu đồ án yêu cầu iOS; nếu không, ghi rõ phạm vi Android/Web |
| REP-01 | P2 | `.idea` đang được theo dõi trong Git | Repo có file cấu hình IDE không cần thiết | Bỏ khỏi Git và thêm quy tắc ignore nếu muốn làm sạch repo |

## Điểm đã đạt

- Không lưu VNPAY Secret Key hoặc Firebase service account trong mã nguồn.
- `payment_orders` bị chặn hoàn toàn đối với client.
- Worker kiểm tra quyền sở hữu booking trước khi tạo URL thanh toán.
- IPN kiểm tra chữ ký HMAC-SHA512, Terminal Code, số tiền và trạng thái.
- IPN dùng precondition/update time để hạn chế cập nhật cạnh tranh.
- Booking đã thanh toán chỉ được xác nhận bởi Worker.
- Voucher dùng transaction và có kiểm tra hạn, lượt dùng, đơn tối thiểu và lịch sử đổi.
- Storage chỉ cho admin tải ảnh, giới hạn ảnh dưới 5 MB.
- README và tài liệu kiến trúc đã mô tả rõ Firebase, Worker và VNPAY Sandbox.

## Cổng chất lượng trước khi phát hành

Các lệnh sau phải thành công:

```powershell
dart format --output=none --set-exit-if-changed .\lib .\test
flutter analyze
flutter test

cd .\cloudflare_worker
npm test
cd ..

flutter build apk --release
flutter build web --release
```

Ngoài ra:

- Không có file Secret Key, service account hoặc keystore trong Git.
- Hoàn thành toàn bộ test case P0/P1 trong `docs/TEST_PLAN.md`.
- Chụp ảnh kết quả kiểm thử để đưa vào báo cáo.
- Tạo tag Git `v1.0.0` sau khi chốt bản demo.
