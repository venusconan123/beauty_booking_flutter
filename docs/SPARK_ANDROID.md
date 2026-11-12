# APK Android, Firebase Spark và backend online

Source chính tại `C:/Users/tranl/men_hair_booking`. Bản chạy bình thường từ
`lib/main.dart` dùng Firebase thật `men-hair-booking` và API Cloudflare HTTPS:

`https://men-hair-booking-vnpay.venusconan23.workers.dev/api/scheduling`

APK không cần máy tính chạy backend hoặc Firebase Emulator. Điện thoại cần
Internet. Dữ liệu tài khoản vẫn ở Firebase Authentication; lịch hẹn, phân ca,
biên nhận và thống kê vẫn ở Firestore của dự án hiện tại. Billing Firebase vẫn
tắt; không triển khai Cloud Functions hoặc nâng Blaze.

## Cấu trúc

- Cloudflare Worker giữ các endpoint VNPAY hiện có và bổ sung API staff/scheduling.
- Dùng lại `functions/src/staff.js`, `scheduling.js`, `loyalty.js`, `write_control.js`
  thông qua adapter REST, thay vì sao chép các quy tắc nghiệp vụ sang một bản khác.
- Worker kiểm tra Firebase ID token với Google, kiểm tra tài khoản đang hoạt động,
  kiểm tra quyền admin/nhân viên, sau đó chạy giao dịch Firestore.
- Link tài khoản hai chiều, guard nhân viên/ngày, chống trùng lịch, retry cùng
  requestId, receipt và audit được giữ trong giao dịch.
- REST adapter gom các lần đọc của bảng phân ca tháng trong cùng giao dịch.
  Kiểm thử đã bao phủ một tháng 31 ngày trong ngân sách subrequest của Workers Free.
- Service-account JSON chỉ là secret trên Cloudflare. Không thêm credential quản
  trị vào Flutter, assets hoặc APK.
- Android release manifest khai báo quyền INTERNET. Mặc định app gọi HTTPS;
  kiểm thử giả lập vẫn dùng `--dart-define=FIREBASE_EMULATORS=true`.

## Đã áp dụng lên Firebase thật

Ngày 12/11/2026:

- Đối chiếu 48 lịch hẹn, 16 document employees (gồm marker), không có lịch đang
  hoạt động thiếu thời gian/thời lượng. Giữ các lịch và hồ sơ hiện có.
- Sao lưu Rules/cấu hình/dịch vụ vào `.firebase/spark-rollout/` trước khi áp dụng.
- Áp dụng Rules server-only đã kiểm thử: client không tự sửa booking, quyền
  nhân viên, lịch làm hoặc biên nhận; các thao tác đó đi qua Worker.
- Thêm index employeeId/dateKey; cả index này và salonId/dateKey đều READY.
- Bổ sung các dịch vụ mặc định còn thiếu bằng create-only, giữ giá/trạng thái
  dịch vụ đã có do admin chỉnh.
- Bật protocolVersion 2 và các cờ staff/roster/booking/payment trên
  `app_settings/scheduling_v2` sau khi index sẵn sàng.
- Worker hiện tại: version `1e3f69f1-d482-44c4-bb38-adafc41fd916`
  (tổng hợp đánh giá thật ngày 13/11/2026; giữ chặn email trùng và đổi ca cùng ngày).

## Kiểm tra và build

```powershell
flutter analyze --no-pub
flutter test --no-pub
node --test cloudflare_worker/test/firestore-rest.test.js cloudflare_worker/test/payment.test.js cloudflare_worker/test/scheduling-security.test.js
flutter build apk --release --no-pub
```

APK: `build/app/outputs/flutter-apk/app-release.apk` (~57 MB). Bản này dùng
debug signing key theo cấu hình release hiện có, phù hợp cài thử/demo. Khi phát
hành lên Play Store cần thiết lập upload key riêng.

`tools/check-spark-online.cjs` kiểm tra API thật bằng một tài khoản thử không có
quyền quản trị, rồi xóa tài khoản thử đó. Nó xác nhận đọc thợ/giờ trống trả 200,
khách không được tạo staff/phân ca (403), không chạm tài khoản/lịch cũ.

Kết quả: 56/56 kiểm thử Firebase/REST, 19/19 kiểm thử Worker/HTTP và 43/43
Flutter đạt; analyzer không có vấn đề. API online đã qua kiểm tra kết nối và
phân quyền. Chưa kiểm thử cài APK trên điện thoại Android thật trong phiên này.

Để xem giao diện dùng cùng API thật trên máy:

```powershell
flutter build web --release --output=build/web-spark --no-web-resources-cdn --no-pub
node tools/serve-spark-web.cjs
```

Mở `http://localhost:7358/`, đăng nhập tài khoản thật của dự án. Không dùng
`local-admin@example.test` hoặc tài khoản giả lập để đăng nhập Firebase thật.

## Kiểm thử Chrome với Firebase thật — 12/11/2026

- Dùng phiên admin thật tại `http://localhost:7358/`, không bật Emulator.
- Đã tạo tài khoản nhân viên và liên kết hồ sơ **Lê Quốc — salon_01** qua
  giao diện. Hộp thoại thành công và danh sách tài khoản đã hiển thị liên kết
  đang bật. Không lưu mật khẩu thử trong source hoặc tài liệu.
- Đã lưu qua giao diện một ô phân ca **12/11/2026, C (14:00–22:00)** cho
  Lê Quốc. Bảng tải lại sau thao tác và hiển thị ký hiệu C.
- Chủ email đã xác minh, đăng nhập và ứng dụng mở đúng tab Lịch làm. Tài khoản
  nhân viên đọc được ca C vừa phân và danh sách lịch được giao.

### Kết quả hoàn thành và thu tiền — rạng sáng 13/11/2026

Lịch riêng `demo_chrome_20261112_lequoc`, khách **KIỂM THỬ DEMO 12/11**,
Lê Quốc, salon_01, ngày hẹn 12/11 lúc 21:30, cắt tóc 80.000đ, trả tại quầy.
Chủ dự án đã xác nhận tạo dữ liệu thử và khoản ghi thu thử trên Firebase thật.
Không có thu/chuyển tiền ngoài đời; số thử vẫn xuất hiện trong thống kê thật.

| Bước trên Chrome | Kết quả đối chiếu |
| --- | --- |
| Nhân viên xác nhận Hoàn thành | `completed`; `completedBy` là UID nhân viên; thanh toán vẫn `unpaid`; chưa có biên nhận |
| Thống kê nhân viên trước thu tiền, ngày hẹn 12/11 | 1 lịch, 1 hoàn thành; dịch vụ 80.000đ; đã thu 0đ; còn chưa thu 80.000đ |
| Admin ghi nhận tiền mặt | `paid`, provider `salon`, environment `manual`, method `cash`, số tiền 80.000đ |
| Kiểm tra biên nhận | `payment.receipt.id = salon_demo_chrome_20261112_lequoc`; có UID admin và thời gian máy chủ; đúng 1 audit `booking.payment.record` |
| Giao diện admin sau thu | Hiện “Đã thu tại salon · Tiền mặt”, biên nhận, người ghi nhận, thời gian; không còn nút thu tiền ở lịch này |
| Dashboard admin, bộ lọc 7 ngày theo ngày tạo | 1 lịch, 1 hoàn thành; giá trị dịch vụ 80.000đ; đã thu 80.000đ; còn chưa thu 0đ |
| Thống kê nhân viên sau thu, ngày hẹn 12/11 | 1 lịch, 1 hoàn thành; dịch vụ 80.000đ; đã thu 80.000đ; còn chưa thu 0đ |
| Đối chiếu dữ liệu cũ trong tháng/30 ngày | 6 lịch, 3 hoàn thành; dịch vụ 380.000đ; đã thu 80.000đ; giữ nguyên 300.000đ chưa thu từ các lịch cũ |

**Giới hạn:** bước bắt đầu phục vụ thành công chưa được kiểm thử qua Chrome.
Khi tiếp tục đã sang ngày 13/11, nút bắt đầu lịch 12/11 bị khóa đúng quy tắc
chỉ bắt đầu trong ngày và đã đến giờ. Theo xác nhận riêng của chủ dự án,
`tools/live-chrome-demo.cjs --prepare-in-service --apply` chuẩn bị riêng lịch
demo thành `in_service`, ghi `startedBy = demo_fixture_setup`, trường
`demoPreparation` và audit `demo.fixture.prepare_in_service`. Đây là chuẩn bị
dữ liệu thử, không phải bằng chứng nhân viên bấm Bắt đầu thành công.
Không đổi thời gian máy, ngày hẹn hoặc quy tắc của backend để ép chạy.

Không phát hiện lỗi mới ở các bước hoàn thành, ghi thu tiền và thống kê trong
lần chạy này. Đã sửa công cụ đối chiếu để đọc đúng biên nhận nhúng tại
`bookings/{id}.payment.receipt` và đếm audit thu tiền, thay vì tìm một collection
biên nhận không được backend sử dụng. Giao diện từng dừng do máy chủ local cổng
7358 kết thúc; đã chạy lại `node tools/serve-spark-web.cjs` và kiểm thử tiếp.

Đối chiếu lại (chỉ đọc, cần phiên Firebase CLI có quyền dự án):

```powershell
node tools/live-chrome-demo.cjs --inspect
```

Script cần biến `FIREBASE_TOOLS_ROOT` trỏ đến thư mục package firebase-tools
đang đăng nhập. Không ghi mật khẩu/token vào source hoặc tài liệu.

## Cập nhật backend sau này

### Đổi ca cùng ngày — bản sửa 13/11/2026

- `swapShifts` cho phép hai ca của **hai nhân viên khác nhau** có cùng ngày;
  vẫn hỗ trợ đổi khác ngày/khác chi nhánh. Chỉ đổi nhân viên nhận ca, giữ ngày,
  giờ và chi nhánh của từng ca.
- Cả hai nhân viên phải không có lịch khách còn hiệu lực trong các ngày được
  chọn ở mọi chi nhánh. Lịch đã hoàn thành/đã hủy không chặn đổi ca.
- Tiếp tục kiểm tra trùng giờ, OFF, nhân viên hoạt động, quyền admin, ngày đã
  qua và revision. Hai ca, guard nhân viên/ngày và audit được lưu nguyên tử;
  đặt lịch đồng thời không thể làm mất kiểm tra xung đột.
- Giao diện giải thích rõ cùng ngày được hỗ trợ và chặn chọn hai ca của cùng
  một nhân viên trước hộp xác nhận.
- Kiểm thử: 61/61 Firebase/REST (gồm đổi cùng ngày qua REST adapter dùng cho
  Worker), 19/19 Worker/HTTP; `flutter analyze --no-pub` không có vấn đề.
  Wrangler dry-run và triển khai online đều thành công. Không tự đổi ca thật
  của người dùng để kiểm thử.
- Source Flutter đã sửa trực tiếp; Hot Restart app đang chạy từ VS Code để
  nạp nội dung hướng dẫn mới. APK/web build cũ chưa được build lại trong lần sửa này.

### Lệnh triển khai

```powershell
cd cloudflare_worker
npx wrangler login
npx wrangler deploy --dry-run
npx wrangler deploy
```

Giữ nguyên các secret `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIREBASE_WEB_API_KEY`,
`VNP_TMN_CODE`, `VNP_HASH_SECRET`. Đổi secret/quyền IAM cần kiểm tra lại API thật.
Hạn mức Firebase Spark và Cloudflare vẫn áp dụng; không cam kết tải không giới hạn.

## Nhân viên đổi mật khẩu — 13/11/2026

- Trong tab **Tài khoản**, nút **Đổi mật khẩu** mở biểu mẫu mật khẩu hiện tại,
  mật khẩu mới và xác nhận. Mật khẩu mới dài 8–128 ký tự, khác mật khẩu hiện tại;
  xác nhận phải khớp. Từng ô mặc định ẩn và có nút hiện/ẩn riêng.
- `PasswordChangeService` dùng Firebase Auth của chính tài khoản đang đăng
  nhập: `reauthenticateWithCredential` với mật khẩu hiện tại trước, rồi mới
  `updatePassword`. Nếu tài khoản thay đổi trong lúc xác thực thì không cập nhật.
- Không lưu mật khẩu vào Firestore hoặc log; không gọi backend Cloudflare,
  không cần triển khai Functions hay thay Rules. Lỗi Firebase được chuyển thành
  thông báo tiếng Việt, không hiển thị nguyên văn thông tin lỗi từ máy chủ.
- Trong lúc gửi, khóa các ô, nút lưu và thao tác quay lại; không gửi lặp. Thành
  công xóa dữ liệu trên biểu mẫu, quay về Tài khoản và thông báo dùng mật khẩu
  mới cho lần đăng nhập sau.
- Kiểm thử: 10/10 kiểm thử dịch vụ/widget cho xác thực lại, mật khẩu sai, phiên
  thay đổi, độ dài/xác nhận, gửi lặp, thông báo thành công và màn hình 320px.
  Flutter analyzer không có vấn đề. Không thay mật khẩu tài khoản Firebase thật
  trong kiểm thử tự động; kiểm thử dịch vụ dùng đối tượng Auth giả lập trong test.
- Hot Restart app chạy từ source để dùng giao diện mới. APK và web build cũ cần
  build lại nếu muốn phát hành chức năng mới trong các gói đó.

## Email đã được sử dụng — 13/11/2026

- Đăng ký khách hàng bằng email đã có trong Firebase Authentication tiếp tục
  nhận lỗi `email-already-in-use`, hiển thị **Email này đã được sử dụng.**
- Admin tạo nhân viên bằng email đã có (khách, nhân viên, admin, chưa xác minh
  hoặc vô hiệu hóa) nhận `already-exists` / HTTP 409, với cùng thông báo.
  `createStaffAccount` không còn tự lấy UID sẵn có rồi gắn quyền nhân viên.
- Thông báo trùng không phụ thuộc mật khẩu nhập giống hay khác. Email nhân viên
  được bỏ khoảng trắng đầu/cuối và chuẩn hóa chữ thường trước khi kiểm tra.
- Firebase Auth kiểm tra trùng một lần nữa khi tạo: nếu khách đăng ký đồng thời
  sau bước kiểm tra email, backend từ chối và không liên kết người đó làm nhân
  viên. Hai yêu cầu tạo trùng chỉ một yêu cầu thành công; yêu cầu còn lại báo
  email đã được sử dụng. Không đổi mật khẩu hoặc tạo thêm audit khi bị từ chối.
- Giao diện admin yêu cầu mật khẩu ban đầu 8–128 ký tự, nút **Tạo tài khoản nhân
  viên**, không còn hướng dẫn để trống mật khẩu cho email đã tồn tại.
- Kiểm thử: 62/62 Firebase/REST, gồm đăng ký khách trùng email nhân viên bằng cùng
  và khác mật khẩu, email khách không bị chuyển vai trò, cạnh tranh đăng ký, và
  phản hồi HTTP 409; 19/19 Worker/HTTP; analyzer không có vấn đề. Đã triển khai
  backend online, không tạo/sửa tài khoản Firebase thật để kiểm thử trường hợp này.

## Điểm nhân viên tự động từ đánh giá thật — 13/11/2026

Trước bản sửa, Lê Quốc có điểm mẫu 4.9 và 119 lượt sinh từ công thức dữ liệu mẫu.
Các trường lịch sử `employees.rating/reviewCount` không còn là nguồn hiển thị.

- API đọc `getBarberRatings` tổng hợp trực tiếp trong một giao dịch Firestore từ
  `reviews/{bookingId}` và lịch hẹn tương ứng. Chỉ tính review có sao nguyên
  1–5, đúng mã lịch, đúng chủ lịch, đúng nhân viên/chi nhánh, lịch `completed`;
  bỏ dữ liệu fixture demo và những dòng thiếu/sai liên kết. Không trả thông tin
  khách hàng/lịch hẹn trong kết quả thống kê.
- Điểm = tổng `barberRating` hợp lệ / số review hợp lệ, hiển thị 1 chữ số thập
  phân. Mỗi lịch chỉ có một review; sửa review cập nhật điểm nhưng không tăng
  lượt. Chưa có review hiển thị **Chưa có đánh giá**, không mặc định 5 sao.
- Không có ô nhập điểm hoặc số lượt ở admin. `Barber.toMap` chỉ chứa thông tin
  hồ sơ; cả `create/update` không gửi hai trường thống kê. Dù giá trị lịch sử
  trong hồ sơ bị thay đổi, kết quả API và màn hình vẫn tính từ reviews/lịch thật.
- Đây là thống kê khi đọc, không phải trigger hay ghi bộ đếm ngầm vào employee.
  Không cần Blaze, thay Rules hay di chuyển/xóa review cũ. Review khách vẫn được
  gửi/sửa qua các luồng hiện có và Rules hiện tại. Backend đối chiếu lại với lịch
  thay vì tin các trường nhân viên/chi nhánh do client gửi.
- Admin, màn chọn thợ và tab Nhân viên trong chi tiết chi nhánh theo dõi review
  và hồ sơ, tự đọc lại thống kê khi thay đổi. Có debounce, bỏ phản hồi cũ đến
  muộn, báo lỗi khi không xác minh được số liệu; hủy kết nối khi rời màn hình
  và tạo kết nối mới khi quay lại tab.
- Tổng hợp hiện đọc các reviews và lấy bookings theo lô 100, phù hợp quy mô
  demo hiện tại. Kiểm thử 101 reviews dùng dưới 10 request Firestore qua REST.
- Kiểm thử: 68 Firebase/REST integration, 1 kiểm thử bổ sung cho thiếu chi nhánh,
  58 kiểm thử Flutter toàn bộ trước bổ sung vòng đời tab và 8 kiểm thử tập trung
  sau bổ sung đó; 19 Worker/HTTP; analyzer không có vấn đề. Backend đã triển khai.
- Kiểm tra API thật: `getBarberRatings` trả 200; Lê Quốc (`barber_03`) có **5.0,
  2 reviews hợp lệ** tại thời điểm kiểm tra. `listBookableStaff/getAvailability`
  vẫn trả 200; khách không có quyền tạo nhân viên/phân ca (403). Tài khoản Auth
  thử đã được xóa; không ghi review hoặc thay hồ sơ nhân viên trên Firebase thật.

Hot Restart app chạy từ source để nạp biểu mẫu và cách hiển thị mới. APK/web
build trước bản sửa cần build lại khi dùng các gói đó.
