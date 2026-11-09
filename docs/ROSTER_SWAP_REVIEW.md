# Đổi đúng hai ô phân ca — quy tắc đã chốt với người dùng

Thay thế cách hoán đổi lịch cả hai ngày ở commit `6c914c2`.

## Hành vi hiện hành

Admin chọn hai ô chứa ca làm của hai nhân viên và bấm Đổi A/B.

- Cho phép chọn hai ca **cùng ngày hoặc khác ngày**.
- Chỉ hoán đổi **loại ca, giờ bắt đầu và giờ kết thúc** giữa hai ô.
- Giữ nguyên ID ca, nhân viên, ngày, chi nhánh, trạng thái và mọi ô không chọn.
- S ↔ S cùng giờ không thay đổi mã ca, không đưa C/OFF từ ô khác vào.
- Không còn lựa chọn hoán đổi toàn bộ lịch cả hai ngày trong giao diện/API cục bộ.
- OFF và ô trống vẫn không được coi là ca làm để chọn đổi; dùng Phân ca/OFF khi
  cần điều chỉnh các ô đó.

Ví dụ đúng với ảnh ngày 04/12/2026:

| Nhân viên | Trước | Sau |
|---|---|---|
| Trần Quốc Bảo | C 14:00–22:00 | S 07:00–15:00 |
| Lê Hoàng Nam | S 07:00–15:00 | C 14:00–22:00 |

Ví dụ chọn Nam S ngày 14 và Bảo S ngày 13: hai ô này vẫn S; Nam OFF ngày 13 và
Bảo C ngày 14 giữ nguyên. Đổi giờ/loại ca không chuyển người sang ô ở ngày khác.

## Kiểm tra trước khi lưu

- Chỉ admin thực hiện, hai nhân viên phải đang hoạt động, không sửa ngày quá khứ.
- Nếu khác ngày: vẫn kiểm tra cả hai nhân viên trong cả hai ngày về lịch khách
  còn hiệu lực, kể cả lịch khách ở chi nhánh khác. Nếu cùng ngày: kiểm tra cả hai
  nhân viên trong ngày đó, không lặp ngày trong phần xem trước.
- Ca mới không được trùng ca/OFF còn lại của chính nhân viên tại mọi chi nhánh.
- Xem trước chỉ có đúng hai ô Hiện tại / Sau đổi. Kiểm tra lại trước khi lưu;
  từ chối nếu dữ liệu đã thay đổi sau lúc xem trước.
- Không tự xóa ca đang cản trở, không thay bốn ô và không ghi một phần khi lỗi.

## Kiểm chứng trong lượt sửa này

- `dart tools/check_workspace_store.dart`: 24 kiểm tra domain đạt.
- `dart tools/check_roster_day_swap.dart`: 23 kiểm tra hồi quy đạt, gồm ảnh C/S cùng
  ngày, giữ nguyên tất cả bản ghi không chọn, khôi phục dữ liệu, S/S không ảnh hưởng
  OFF/C, đổi khác ngày, bốn trường hợp có lịch khách xuyên chi nhánh, trùng giờ
  với ca bổ sung, xem trước cũ, tài khoản ngừng hoạt động và quyền nhân viên.
- Kiểm tra tĩnh phần mã mới bằng Dart analyzer, không thêm dependencies.
- Chưa kiểm thử tương tác Flutter Web của bản sửa trong môi trường này.

Dữ liệu localStorage hiện có được giữ, không cần xóa lịch hoặc database. Mở lại:

```powershell
git pull --ff-only
flutter run -d chrome -t lib/main_preview.dart
```

Bản sửa thuộc giao diện dùng dữ liệu cục bộ. Không deploy hoặc sửa backend Firebase.
