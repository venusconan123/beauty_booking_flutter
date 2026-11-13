# Chạy và kiểm tra demo đồ án

Bản APK dùng Firebase thật và backend online đã có hướng dẫn riêng tại
[SPARK_ANDROID.md](SPARK_ANDROID.md). Các bước dưới đây dành cho bản giả lập cục bộ.

Source chính: `lib/main.dart`, Firebase Emulator project `demo-men-hair-booking`.
Không dùng `main_preview.dart` cho luồng nghiệp vụ này. Giữ gói Spark hiện có.

## Khởi động

Cần Node 22, Java 21 trở lên, Firebase CLI và Flutter. Script kiểm tra phiên bản,
đưa đúng Node/Java lên đầu PATH cho cả tiến trình con, chờ Functions nạp tối đa
180 giây. Script web kiểm tra OPTIONS của các worker đặt lịch, phục vụ, thu tiền
và phân ca trước khi mở web; không gửi yêu cầu ghi dữ liệu khi kiểm tra.

Nếu Node 22 và Firebase CLI đã có trong PATH, tại thư mục dự án:

```powershell
# Terminal 1: để chạy suốt buổi demo
./tools/start-local-emulators.ps1

# Terminal 2: kiểm tra worker rồi mở ứng dụng
./tools/run-local-web-preview.ps1
```

Máy hiện tại có Node 24 trong PATH; bộ Node 22 và Firebase CLI đã dùng để kiểm thử
nằm trong cache cài đặt trước đó. Có thể chạy Terminal 1 bằng các tham số sau:

```powershell
$toolCache = Join-Path $env:LOCALAPPDATA 'Temp/men-hair-booking-firebase-audit-cache/_npx'
$demoNode = Join-Path $toolCache '52027bd8fc0022aa/node_modules/node/bin/node.exe'
$demoCli = Join-Path $toolCache 'ba4f1959e38407b5/node_modules/firebase-tools/lib/bin/firebase.js'
./tools/start-local-emulators.ps1 -NodePath $demoNode -FirebaseCliPath $demoCli
```

Script tự dùng JDK của Android Studio nếu chưa đặt JAVA_HOME; có thể truyền
`-JavaHome 'đường dẫn thư mục JDK'`. Nếu cache công cụ bị dọn, cài Node 22 và
Firebase CLI rồi dùng lệnh mặc định ở trên.

Mở `http://localhost:7359/` cho khách/admin và `http://127.0.0.1:7359/` cho nhân viên
để hai phiên đăng nhập độc lập. Cùng hostname sẽ dùng chung phiên đăng nhập.

## Dữ liệu và tài khoản

Script tự nhập `.firebase/demo-data` khi có bản lưu. Lần đầu có thể nhập checkpoint
`.firebase/monthly-review-20261109`. Dừng Terminal 1 bằng **Ctrl+C một lần**, chờ
**Export complete**. Bản lưu gồm Auth và Firestore, được Git bỏ qua. Tắt cưỡng bức
tiến trình trước khi xuất xong có thể mất thao tác từ lần lưu gần nhất.

Các tài khoản chỉ dùng trong giả lập, mật khẩu chung `Local-demo-123!`:

| Vai trò | Email |
| --- | --- |
| Khách | local-customer@example.test |
| Nhân viên | local-staff@example.test |
| Admin | local-admin@example.test |

Để bổ sung dữ liệu mẫu cho ngày trình bày, khi giả lập đã chạy:

```powershell
$env:GCLOUD_PROJECT = 'demo-men-hair-booking'
$env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
node functions/tools/seed-local.cjs
```

Seed tạo phần còn thiếu, không đặt lại các lịch đã hoàn thành/thanh toán.

## Kịch bản trên giao diện

1. Khách chọn chi nhánh Nguyễn Văn Linh → cắt tóc + gội đầu → Nhân viên demo →
   một giờ trống → thanh toán sau. Tổng 110.000đ; lịch xác nhận tự động.
2. Nhân viên đăng nhập vào tab Lịch làm, chuyển Lịch hẹn → Hôm nay.
   Có thể bắt đầu sớm trong cùng ngày khi khách đã đến, đang trong ca,
   không có khách đang phục vụ và không chồng lịch hẹn còn hiệu lực.
3. Bắt đầu phục vụ → Hoàn thành. Với lịch thanh toán tại quầy, xác nhận hoàn thành
   đồng thời xác nhận đã nhận đủ tiền, tự tạo biên nhận và tăng số đã thanh toán.
4. Admin xem lịch hoàn thành và biên nhận; không cần thu thêm lần nữa.
   Nút ghi nhận thanh toán vẫn dùng cho lịch cũ đã hoàn thành nhưng chưa thu.
5. Lịch hiển thị đã thu tại salon. Thống kê nhân viên
   cập nhật trực tiếp; dashboard admin tách giá trị dịch vụ, tiền đã thu và còn chưa thu.

## Bằng chứng kiểm thử 12/11/2026 (luồng cũ, trước tự thanh toán khi hoàn thành)

Lịch **wSefTjxaDY5bR3yvRnF4**, 19:00 ngày 12/11/2026, được tạo và xử lý qua
giao diện thật trên giả lập: khách đặt → nhân viên bắt đầu → nhân viên hoàn thành →
admin ghi nhận 110.000đ tiền mặt. Không đổi đồng hồ hệ thống hoặc bỏ điều kiện giờ hẹn.

| Thống kê nhân viên trong tháng | Trước phục vụ | Hoàn thành, chưa thu | Đã thu |
| --- | ---: | ---: | ---: |
| Lịch hoàn thành | 2 | 3 | 3 |
| Giá trị dịch vụ | 160.000đ | 270.000đ | 270.000đ |
| Đã thanh toán | 80.000đ | 80.000đ | 190.000đ |
| Còn chưa thu | 80.000đ | 190.000đ | 80.000đ |

Bộ lọc ngày 12/11: 1 lịch hoàn thành, dịch vụ 110.000đ, đã thanh toán 110.000đ,
còn chưa thu 0đ. Số liệu mẫu khác vẫn được giữ nguyên.

Dashboard admin sau thu: 5 lịch hoàn thành, giá trị dịch vụ 430.000đ, đã thu
270.000đ, còn chưa thu 160.000đ (trước luồng: 4 lịch, 320.000đ, 160.000đ,
160.000đ). Đã tắt giả lập bằng Ctrl+C, thấy Export complete, mở lại từ
`.firebase/demo-data` và đối chiếu đúng lịch/biên nhận cùng các số liệu này trên UI.
Sau khởi động lại, cả 9 worker kiểm tra đều trả 204 ngay lần đầu, không có lỗi
Failed to load function trong log của lần chạy mới.

Ảnh từng bước được lưu trong `build/demo-validation/ui-*.png` (artifact cục bộ).
`tools/inspect-demo-booking.cjs <mã lịch>` đọc lại bản ghi để đối chiếu;
script chỉ chấp nhận project demo và đúng cổng giả lập, không sửa dữ liệu.

Kiểm thử tự động: Firebase **54/54**, Flutter **43/43**, analyzer không có vấn đề.
Bộ Firebase bao gồm retry, thu trùng đồng thời, phân quyền và cả tiền mặt/chuyển khoản.
Có thể chạy lại bằng `start-local-emulators.ps1 -RunTests` với cùng tham số công cụ;
bộ test dùng các cổng 9199/8180/5101, không nhập dữ liệu demo đang trình bày.

Đây là bản demo chạy cục bộ. Chưa bật Blaze hoặc triển khai Functions production.
