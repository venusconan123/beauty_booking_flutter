# Men Hair Booking — giao diện duyệt trước database

Nguồn ban đầu: `fab7765` trên `codex/staff-phase-one`.

## Mở giao diện

Từ thư mục Flutter của dự án, sau khi lấy nhánh `codex/full-ui-local`:

```powershell
flutter pub get
flutter run -d chrome -t lib/main_preview.dart
```

Hoặc dùng entry point cũ và cờ riêng:

```powershell
flutter run -d chrome --dart-define=UI_PREVIEW=true
```

Hai cách đều vào giao diện mới **trước khi khởi tạo Firebase**. Không cần chạy
Emulator, tạo database, bật billing hay nhập tài khoản cloud. Khi không bật cờ và
không chọn entry point mới, ứng dụng vẫn dùng luồng Firebase hiện có.

Màn hình mở đầu cho phép xem biểu mẫu đăng nhập/đăng ký, vào không gian khách hàng,
hoặc chọn Admin / một trong sáu nhân viên. Đây là **chọn vai trò để duyệt**, không
phải cơ chế xác thực hoặc phân quyền production. Không nhập mật khẩu thật.

Trên Web, thay đổi tự lưu ở localStorage `men-hair-booking-ui-v1`, cùng origin/cổng.
Trên native, trạng thái chỉ tồn tại trong phiên. Admin có thể sao chép JSON trong
Cài đặt để giữ một bản dữ liệu giao diện. Không có thao tác ghi Firebase.

## Màn hình và hành động đã có trong mã

| Không gian | Giao diện và thao tác |
|---|---|
| Khách hàng | Đăng nhập/đăng ký biểu mẫu cục bộ; trang khám phá; dịch vụ; bộ sưu tập kiểu tóc; chi nhánh; chỉ đường Maps; gọi hotline; đặt lịch 4 bước; nhiều dịch vụ; lựa chọn thợ/ngày/giờ theo ca; voucher; xác nhận; lịch sử và hủy trước phục vụ; chỉnh hồ sơ; hỏi đáp và nhắn hỗ trợ |
| Nhân viên | Lịch được giao; lọc trạng thái/ngày/tìm kiếm; chi tiết; bắt đầu phục vụ trong ngày; hoàn thành một lần; bảng ca cùng chi nhánh chỉ đọc; báo cáo cá nhân ngày/tuần/tháng/năm; hồ sơ chỉ đọc |
| Admin | Tổng quan; lịch toàn hệ thống; bắt đầu/hoàn thành/hủy; ghi thu một phần hoặc đủ; bảng phân ca tháng; chọn nhiều ô; lặp theo thứ; ca tùy chỉnh; OFF; hủy ca; đổi A/B; xếp nhân viên xuyên chi nhánh; quản lý nhân viên/dịch vụ/voucher; thống kê theo chi nhánh/nhân viên; sao chép CSV; trả lời hỗ trợ; nhật ký và xuất JSON |

Desktop dùng thanh điều hướng bên trái, mobile dùng thanh dưới và menu Thêm.
Bảng phân ca tái sử dụng `MonthlyRosterGrid` hiện có: cố định tên nhân viên và tiêu
đề ngày, cuộn ngang ngày và đồng bộ cuộn dọc. Bộ điều khiển có vùng cuộn riêng
trên màn hình thấp. Nội dung dài dùng danh sách cuộn và các cụm nút xuống dòng.

Dữ liệu ban đầu gồm 3 chi nhánh, 6 nhân viên, danh mục dịch vụ hiện có, voucher,
lịch hôm nay, lịch hoàn thành trước đó và các ca minh họa S/C/HC/F/OFF. Ngày mẫu
được tính tương đối theo ngày Việt Nam lúc mở ứng dụng, không cố định tháng 12.

## Nghiệp vụ cục bộ đi cùng giao diện

- Giá và thời lượng lấy từ danh mục cục bộ, không nhận giá tùy ý từ biểu mẫu.
- Giờ đặt phải nằm trọn một ca tại chi nhánh và không trùng lịch còn hiệu lực.
- Yêu cầu đặt lịch lặp cùng mã/nội dung trả cùng kết quả. Đổi nội dung cùng mã bị chặn.
- Hủy lịch giải phóng giờ; không tự hoàn lại lượt voucher đã sử dụng.
- Nhân viên chỉ xử lý lịch của mình; ngừng hoạt động chặn xử lý ngay trong phiên.
- `confirmed → in_service → completed`; lịch hoàn thành có một bản chụp cố định
  dịch vụ, giá và số phải thu. Chỉnh danh mục sau đó không đổi lịch sử.
- Biên nhận ghi thu có mã riêng; gửi lại không nhân đôi, không thu quá công nợ.
- Thống kê theo ngày hoàn thành Việt Nam; tuần thứ Hai–Chủ nhật. Một lịch hai
  dịch vụ tính một lịch và hai lượt. Đã thu/công nợ lấy từ những lịch hoàn thành
  trong kỳ, đối soát ở thời điểm xem; không gọi đó là dòng tiền thu trong kỳ.
- Phân ca nhiều ô kiểm tra toàn bộ trước khi thay đổi; giữ ca cũ ở trạng thái hủy.
  Chặn OFF khi có khách, ca không bao phủ lịch khách, trùng giờ/OFF xuyên chi nhánh.
- Đổi A/B kiểm tra cả hai nhân viên ở cả hai ngày trên mọi chi nhánh, sau đổi
  không được trùng ca. Có thông báo chỉ rõ người/ngày/giờ/chi nhánh xung đột.

## Chưa được coi là tích hợp dịch vụ thật

- Biểu mẫu tài khoản chưa xác thực Firebase Auth; quên mật khẩu hiện giải thích
  bước tích hợp, chưa gửi email. Email hồ sơ nhân viên chưa liên kết UID thật.
- Đặt lịch ở bản duyệt dùng thanh toán tại salon. Không gọi VNPay hoặc giả nhận
  giao dịch ngân hàng thành công. Luồng VNPay cũ trong dự án được giữ nguyên.
- Hỗ trợ là hội thoại cục bộ và câu hỏi thường gặp; **chưa có mô hình chatbot AI**.
- Chỉ đường mở Maps bên ngoài với tọa độ chi nhánh có sẵn; chi nhánh Sơn Trà
  vẫn được ghi rõ là địa điểm mô phỏng, không xác nhận đây là salon thật.
- Dữ liệu trình duyệt không chia sẻ giữa máy, không phải database dùng chung.
- Các kiểm tra trên client giúp duyệt hành vi; khi nối backend phải kiểm tra lại
  quyền, giá, xung đột, voucher và idempotency bằng Functions/transaction/Rules.

## Kiểm tra đã thực hiện trong lượt này

- 24 kiểm tra domain chạy bằng Dart, không khởi tạo Flutter/Firebase, tại
  `tools/check_workspace_store.dart`: đặt/hủy, trùng giờ, voucher, quyền nhân viên,
  hoàn thành và biên nhận không trùng, giữ giá lịch sử, phân ca nguyên tử,
  OFF, trùng xuyên chi nhánh, đổi A/B, khóa nhân viên, ranh giới tuần, xuất và
  khôi phục trạng thái, phạm vi báo cáo cá nhân.
- Phân tích tĩnh mã mới bằng Dart analyzer với mã nguồn Flutter SDK và các package
  liên quan được ánh xạ cục bộ; không thay pubspec hoặc package của dự án.
- Biên dịch bộ kiểm tra domain sang JavaScript bằng dart2js, chạy lại 24 kiểm tra
  trên Node với localStorage mô phỏng: đạt; adapter Web ghi được dữ liệu. Đây
  không phải kiểm thử widget hoặc thao tác trong trình duyệt.
- Định dạng Dart và kiểm tra whitespace của diff.
- **Chưa chạy Flutter build, widget tests hoặc kiểm chứng tương tác Web của mã mới.**
  Lần khởi động Flutter SDK bị kiểm duyệt tự động chặn khi tiến trình thử truy cập
  endpoint metadata máy chủ. Không thử vượt chặn; dùng kiểm tra Dart cục bộ thay thế.
  Kết quả Web/Flutter/Emulator của commit trước không được dùng làm bằng chứng cho
  giao diện mới này.

Chạy lại domain checks tại máy phát triển:

```powershell
dart tools/check_workspace_store.dart
```

Sau khi chạy Web ở máy phát triển, cần kiểm chứng: giao diện 390px và desktop;
đặt lịch khách → đổi sang đúng nhân viên → bắt đầu/hoàn thành → admin ghi thu →
thống kê thay đổi; tải lại trang giữ dữ liệu; phân ca nhiều ô/OFF; đổi A/B hợp lệ
và xung đột; nhân viên không có nút sửa; tạo/sửa/ngừng hoạt động danh mục.

## Bước nối database sau khi duyệt

Giữ cấu trúc màn hình và thay nguồn dữ liệu trong `WorkspaceStore` bằng adapter
đọc/ghi backend. Xác thực vai trò từ UID, không dùng bộ chọn vai trò của bản duyệt.
Map hồ sơ → employees/staff_accounts, ca → work_shifts, lịch → bookings, chốt dịch
vụ → booking_completions, chứng từ → payment_receipts. Dữ liệu mẫu không tự động
được nhập vào database. Phần backend đã có trong dự án cần đối chiếu hợp đồng
field/endpoint trước khi ghép. Không bật billing/deploy trong gói giao diện này.
