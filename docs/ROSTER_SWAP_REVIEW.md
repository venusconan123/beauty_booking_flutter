# Đổi hai ca và hoán đổi lịch cả hai ngày

Bản sửa trên nhánh `codex/full-ui-local`, tiếp nối `8d8dbfa`.

## Nguyên nhân thông báo trong ảnh

Đổi riêng ca HC ngày 10/01/2027 của Lê Hoàng Nam và ca C ngày 08/01/2027 của
Trần Quốc Bảo sẽ để lại ca F ngày 10/01 của Bảo. Bảo nhận thêm HC sẽ trùng F.
Thông báo trùng là hợp lệ đối với thao tác chỉ đổi hai ca.

Bổ sung cách đổi thứ hai, do admin chủ động chọn; không tự hủy ca hoặc bỏ kiểm tra.

## Cách dùng

1. Chọn hai ca làm của hai nhân viên ở hai ngày khác nhau, rồi bấm Đổi A/B.
2. Trong hộp thoại, chọn một trong hai cách:
   - **Chỉ đổi 2 ca đã chọn**: giữ các ca/OFF khác nguyên trạng. Nếu trùng thì
     hiển thị lý do và không cho xác nhận.
   - **Hoán đổi lịch cả 2 ngày**: đổi người phụ trách của **toàn bộ ca/OFF của
     hai người trong hai ngày trên tất cả chi nhánh**. Ngày, giờ và địa điểm ca
     giữ nguyên. Bao gồm cả hai ô không được chọn ban đầu và ca bổ sung nếu có.
3. Xem phần Hiện tại / Sau đổi của cả bốn ô, bao gồm tên chi nhánh và số ca/OFF
   bị ảnh hưởng. Xác nhận chỉ khả dụng khi kế hoạch hợp lệ.
4. Khi lưu, kiểm tra lại quyền, nhân viên đang hoạt động, ngày không ở quá khứ,
   cả bốn điều kiện lịch khách, toàn bộ khoảng giờ và bản xem trước còn đúng.

Với trường hợp trong ảnh, lựa chọn hoán đổi cả hai ngày cho kết quả:

| Ngày | Nhân viên | Trước | Sau |
|---|---|---|---|
| 08/01/2027 | Lê Hoàng Nam | S | C |
| 08/01/2027 | Trần Quốc Bảo | C | S |
| 10/01/2027 | Lê Hoàng Nam | HC | F |
| 10/01/2027 | Trần Quốc Bảo | F | HC |

OFF đi cùng lịch ngày trong chế độ hoán đổi toàn bộ và được liệt kê trong bản
xem trước. Vẫn phải chọn hai ô chứa ca làm để xác định cặp nhân viên/ngày; không
thay đổi quy tắc chọn OFF hoặc ô trống của nút Đổi A/B hiện có.

## Xác minh

- 24 kiểm tra domain cũ: đạt sau khi bổ sung chế độ mới.
- 21 kiểm tra mới tại `tools/check_roster_day_swap.dart`: tái hiện ảnh; xem trước
  không ghi; đổi đủ bốn ô; một audit; khôi phục dữ liệu; lần lượt bốn trường hợp
  có lịch khách kể cả khác chi nhánh; không ghi một phần khi bị chặn; OFF;
  nhiều ca xuyên chi nhánh; bản xem trước cũ; khóa nhân viên; quyền nhân viên.
- Kiểm tra tĩnh mã mới bằng Dart analyzer; không thay dependencies.
- Chưa chạy kiểm thử tương tác Flutter Web trong môi trường này. Bản sửa chỉ
  áp dụng nguồn dữ liệu cục bộ của giao diện duyệt, chưa đổi backend Firebase.

```powershell
dart tools/check_workspace_store.dart
dart tools/check_roster_day_swap.dart
flutter run -d chrome -t lib/main_preview.dart
```

Dữ liệu localStorage hiện có được giữ; không cần xóa hoặc tạo lại database.
