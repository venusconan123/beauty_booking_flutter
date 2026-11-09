# Bản xem trước chuyển bảng phân ca sang Firebase thật

> Cập nhật mã cục bộ sau rà soát: xem [PRODUCTION_PREP_LOCAL_REVIEW.md](PRODUCTION_PREP_LOCAL_REVIEW.md).
> Các phát hiện transport/gate/voucher/callback bên dưới là baseline f7cb96e;
> nhiều mục đã sửa cục bộ và kiểm thử Emulator, chưa áp dụng lên cloud.

Ngày kiểm tra: 09/11/2026, khoảng 11:00–11:15 giờ Việt Nam.
Commit được rà soát: `f7cb96ed359ea100793cd5f7d9816bd07f1dc804` trên
`codex/staff-phase-one`. Project cố định: `men-hair-booking`, database `(default)`.

**Kết luận: CHƯA SẴN SÀNG triển khai.** Các file mới trong lần rà soát này chỉ
là bản xem trước cục bộ. Chưa sửa mã chạy, Rules hiện hành, billing, IAM, dữ liệu,
tài khoản hoặc dịch vụ cloud; chưa commit/push các bản xem trước.

## 1. Kết quả chỉ đọc trên Firebase thật

| Hạng mục | Kết quả quan sát |
| --- | --- |
| Database | Firestore Standard / Native, `asia-southeast1`, concurrency PESSIMISTIC |
| Billing | `billingEnabled=false`; chưa thể coi là đã có điều kiện triển khai Functions |
| Cloud Functions | API trả 403 SERVICE_DISABLED; **chưa xác minh được inventory Functions**, không suy ra danh sách trống |
| IAM tài khoản CLI | 23 quyền được hỏi đều có, `missing=[]`: đọc dữ liệu, tạo index, tạo/cập nhật Rules/Functions, export/import, xem backup, build/upload, actAs, enable API |
| Giới hạn IAM | Chưa kiểm tra quyền gắn billing account, bucket backup, service agents hoặc runtime service account cụ thể; không tự cấp quyền |
| Indexes | Không có composite index và không có fieldOverrides qua CLI hiện tại |
| Backup | Không có backup hoặc backup schedule được API liệt kê; PITR tắt |
| Bảo vệ database | deleteProtection hiện tắt; đề nghị chủ dự án duyệt bật trước cutover, chưa thay đổi |
| Auth | 6 tài khoản, 4 đã xác minh email, 0 disabled; UID admin hiện có tồn tại trong Auth; không đọc password hash của người dùng |
| Nhân viên | 16 documents gồm `_catalog` và 15 hồ sơ; mỗi chi nhánh 5 người, `isActive` hiện diện |
| Dịch vụ | Chỉ có `service_combo_10`; giá/thời lượng hợp lệ. Thiếu 6 ID dịch vụ mà giao diện đang bổ sung từ fallback |
| Liên kết và ca | `staff_accounts=0`, `employee_accounts=0`, `work_shifts=0` |
| Lịch hẹn | 48: 26 cancelled, 21 completed, 1 confirmed. Tất cả có timestamp/thời lượng và barberId đối chiếu được với hồ sơ nhân viên |
| Schema cũ | 48/48 chưa có schemaVersion 2 và workShiftId; 18 lịch thiếu payment.choice. Không sửa hồi tố để chỉ làm đẹp schema |

Tám collection nêu trên đều dưới 200 bản ghi và đã được đọc đủ ở thời điểm kiểm
tra, có field mask giới hạn. Đây không phải ảnh chụp transaction nhất quán của
toàn database; cần đọc lại trước apply. Chưa thống kê toàn bộ collection phụ,
Storage hoặc cấu hình triển khai Cloudflare.

Lịch confirmed còn lại ở `salon_01`, **02/11/2026 09:30–10:30 giờ Việt Nam**,
pay_later/unpaid. Ngày đã qua nhưng trạng thái còn hiệu lực: cần đối chiếu nghiệp
vụ, không tự hoàn thành/hủy hoặc tạo ca quá khứ.

Rules online hiện hành cập nhật 30/09/2026, ruleset
`projects/men-hair-booking/rulesets/03742ce9-465a-4c50-95f7-16d8a2ce3bde`.
SHA-256 file online:
`0c3d87db843b440e61d7c1ea5af1cc1ffd7fb79158c743880b52b000bf9d12b9`.
Đã lưu bản Rules chỉ đọc trong `.dart_tool/production-readonly/` bị Git bỏ qua;
chưa tạo bản sao lưu database/Auth thật.

## 2. Phần còn chỉ chạy Emulator và tác động nếu phát hành ngay

| Mã nguồn | Hiện trạng | Thay đổi cần chuẩn bị, chưa thực hiện |
| --- | --- | --- |
| `SchedulingService` | Từ chối khi FIREBASE_EMULATORS=false; endpoint HTTP localhost / demo project | Transport production qua callable HTTPS đúng project/region; ưu tiên cloud_functions SDK, cấu hình App Check và timeout/idempotency tương đương |
| `BookingService`, chọn giờ, admin lịch hẹn | Đã chuyển hoàn toàn sang SchedulingService | Bản production mới hiện không đặt/hủy/sửa dịch vụ/xác nhận/hoàn thành được; phải sửa transport trước phát hành |
| `StaffAccountService` và màn hình liên kết | Chỉ localhost; nút liên kết/bật tắt bị khóa ngoài Emulator | Bật theo capability của backend production, không dùng cờ Emulator làm quyền nghiệp vụ |
| `BarberService.watchBySalon` | Chỉ Emulator mới lọc thợ có ca; production vẫn đọc toàn bộ thợ active | Dùng cùng logic ca/availability ở cả hai môi trường; tránh hiện thợ không có ca |
| `main.dart` + Web bootstrap | Demo project/Auth bootstrap chỉ chạy khi cờ Emulator bật; production dùng FirebaseOptions thật | Giữ tách môi trường, bản production không chứa cờ demo; kiểm thử Web/Android thật ở staging trước |
| `firebase.json` | Chưa có block functions | Cấu hình đề xuất ở `firebase.production.preview.json`; không tự đổi file cấu hình đang dùng |
| Nhân viên/Thống kê | Nhân viên xem lịch được giao và bảng chi nhánh; thống kê là placeholder | Không hứa đã có bắt đầu/hoàn thành bởi nhân viên hoặc thống kê 2B/2C; chưa đưa thêm vào phạm vi |
| Thanh toán | Flutter và backend vẫn dùng VNPAY sandbox; có Worker riêng ghi Firestore | Firebase thật không đồng nghĩa VNPAY live. Giữ tách đợt nâng cấp cổng thanh toán và không mang khóa demo sang cloud |

Tên/giờ chi nhánh vẫn được khai báo trong cả `sample_salons.dart` và `SALONS`
backend: cả ba 07:00–22:00, chi nhánh 3 còn tên “30Shine Sơn Trà (mô phỏng)”.
Cần người quản lý xác nhận các giá trị này trước khi ghi salonName vào lịch
khách thật; chưa tự đổi ID hoặc tên chi nhánh trong dữ liệu hiện có.

Không được bật FIREBASE_EMULATORS trên bản phát hành để lách chặn transport:
điều đó nối app về project demo/localhost và không giải quyết production.

## 3. Functions, Rules và indexes cần triển khai sau khi được duyệt

Functions Gen 2, Node 22, region `asia-southeast1`, codebase đề xuất `staff`:

| Nhóm | Tên export | Dữ liệu có thể ghi khi được gọi |
| --- | --- | --- |
| Tài khoản | linkStaffAccount, setStaffAccountActive | Hai chiều liên kết, active, audit; không tạo Auth user |
| Phân ca | saveRoster, saveShifts, cancelShift, swapShifts | work_shifts, guards, operation receipts, audit; thay/hủy mềm |
| Lịch khách | createBooking, updateBookingServices, changeBookingStatus | bookings, booking_slots, guards, receipts, voucher/redemption, notification/audit liên quan |
| Chỉ đọc nghiệp vụ | getAvailability, listBookableStaff | Không ghi dữ liệu nghiệp vụ |
| Dọn slot có kiểm soát | releaseStaleSlots | Đánh dấu released cho slot của booking kết thúc, audit; không xóa |

Module load không seed/migrate và không ghi dữ liệu. Tuy nhiên triển khai
Functions vẫn tạo tài nguyên cloud và có thể phát sinh chi phí. Cần duyệt billing,
API Cloud Functions/Cloud Run/Cloud Build/Artifact Registry liên quan và xác minh
runtime identity tối thiểu, quota/maxInstances, logging và cảnh báo chi phí trước.
Không coi project-level IAM test là bảo đảm toàn bộ deploy sẽ thành công.
[Điều kiện triển khai Functions](https://firebase.google.com/docs/functions/get-started).

Phải có server maintenance gate trước cutover/rollback; hiện source chưa có gate
này. Cờ ẩn nút ở client không chặn client cũ hoặc request tự gửi. App Check chưa
enforce; chuẩn bị client/provider trước khi bật enforce để tránh khóa ứng dụng cũ.
[Callable và token](https://firebase.google.com/docs/functions/callable).

Rules đề xuất của commit so với online:

- Thêm đọc staff_accounts/employee_accounts theo chủ thể/admin; ghi chỉ backend.
- Nhân viên active, email verified, liên kết hai chiều mới đọc lịch được giao và
  lịch làm cùng chi nhánh chính; admin giữ quyền quản lý qua backend.
- Chặn mọi client ghi bookings/booking_slots/work_shifts/guards/receipts; thêm audit
  chỉ admin đọc. Không xóa hồ sơ employees; dùng isActive.
- **Ứng dụng cũ đang ghi booking/slot trực tiếp sẽ lỗi permission-denied.** Không
  deploy Rules mới khi chưa có bản client thay thế và cửa sổ chuyển đổi.
- **Ngược lại**, chạy backend mới cùng Rules cũ vẫn cho phép client bỏ qua guard,
  nên không bảo đảm chống trùng toàn hệ thống. Không để chế độ chuyển tiếp này
  thành trạng thái vận hành lâu dài.
- AccountRoleGate bản mới đọc staff_accounts ngay cả với khách. Rules online
  chưa cho đọc path đó; phát hành app mới trước Rules phù hợp có thể chặn khách
  đăng nhập ở màn hình kiểm tra quyền.

Diff chính xác nằm ở `production-preview/live-to-candidate.rules.patch`.
Rules candidate vẫn có phát hiện cần xử lý trước production: consumer có thể
tăng usedCount của voucher template nhiều lần dựa vào cùng booking đã dùng mã;
booking_slots đọc rộng cho mọi tài khoản; các luồng reports/support có trường
không giới hạn đầy đủ. Đây là đường cũ được kế thừa, không phải do bảng tháng.
Đánh giá tĩnh và khuyến nghị riêng: `production-preview/rules-audit.json`.
Chưa thử khai thác trên dữ liệu thật và chưa sửa Rules để xử lý các mục này.

Index mới duy nhất hiện cần: collection `work_shifts`, queryScope COLLECTION,
`salonId ASC, dateKey ASC`, trong `firestore.indexes.json`. Giữ single-field
indexes mặc định. Staff bookings hiện sort trong client nên chưa cần composite
barberId/appointmentAt. Phải đợi index READY và chạy query thực tế ở staging;
Emulator không chứng minh index cloud đã sẵn sàng. Re-read inventory trước deploy
và merge index mới nếu có người bổ sung index trong thời gian chờ.

Không đưa Storage Rules, Hosting hay Worker vào cấu hình deploy của đợt này.
Không chạy deploy toàn project hoặc xóa export Functions/index cũ khi chưa
kiểm kê được tài nguyên online sau khi API được chủ dự án bật.

## 4. Dữ liệu bổ sung và phần phải giữ nguyên

Bản xem trước có cấu trúc: `production-preview/data-change-preview.json`.

1. Đề xuất tạo **6 service documents còn thiếu**, chỉ create-if-absent và phải
   duyệt giá/thời lượng từ fallback hiện tại: cắt 80.000đ/30p; gội 30.000đ/20p;
   tạo kiểu 50.000đ/30p; uốn 250.000đ/120p; nhuộm 300.000đ/150p;
   chăm sóc da 100.000đ/45p. Giữ nguyên combo hiện có. Không đổi snapshot dịch vụ
   hoặc giá trong lịch hẹn cũ. Làm rõ UI dịch vụ nào thực sự được kinh doanh.
2. Giữ 15 employee IDs, chi nhánh chính, trạng thái và 6 Auth UID hiện có.
   Người quản lý chọn bảng ánh xạ UID ↔ employeeId cụ thể; chưa có ánh xạ được
   duyệt nên số link sẽ tạo còn chưa xác định. Không tự ghép theo tên/email.
   Mỗi người được duyệt tạo 2 link documents + audit qua callable; Auth phải tồn
   tại, enabled và email verified. Không dùng UID admin làm tài khoản nhân viên.
   Nếu chưa có tài khoản riêng, đó là bước provisioning cần duyệt riêng; không
   đổi mật khẩu/UID/tài khoản cũ trong đợt chuyển đổi dữ liệu này.
3. Admin duyệt ngày/ca thực tế cho 3 chi nhánh. Không mặc định cho cả 15 người
   làm F cả tháng, không import lịch demo, không tự biến ô trống thành OFF.
   Cần có ca cho cửa sổ đặt lịch 7 ngày trước khi mở đặt lịch mới; bằng không
   backend trả không có giờ trống. Tạo ca qua preview + expected revisions,
   requestId ổn định và guard chung. Nếu đến lúc apply phát sinh lịch tương lai,
   ca phải bao phủ chúng trước; không thay barberId để khớp lịch giả.
4. 47 lịch đã kết thúc: giữ nguyên IDs, timestamp, giá/dịch vụ, thanh toán và
   trạng thái. Không cần backfill workShiftId cho lịch sử để đọc được. Lịch còn
   confirmed ngày 02/11 cần con người quyết định kết quả thực tế. Chưa có lệnh
   cập nhật booking trong preview. 18 payment.choice thiếu ở lịch sử không được
   tự suy đoán là unpaid/pay_later.
5. employee_days, schedule_operations, audit_events và slot mới do backend tạo
   theo thao tác; không cần seed sẵn. Giữ guards/receipts qua rollback; không xóa
   receipt hoặc bật TTL tùy tiện làm mất chống lặp.

Liên kết một Auth vốn là khách sẽ chuyển giao diện đó sang workspace nhân viên;
lịch hẹn khách cũ không bị xóa nhưng chưa có luồng đổi vai trò trong portal.
Link bất biến kể cả inactive: setStaffAccountActive(false) chặn portal và giữ cả
hai link, không trả tài khoản về vai trò khách. Phải kiểm thử/chuẩn bị tắt portal
có kiểm soát khi rollback, không coi thao tác tắt active là unlink.

## 5. Ảnh hưởng tới hệ thống hiện có

| Luồng | Nguy cơ hoặc việc cần xác nhận |
| --- | --- |
| Đặt/hủy/đổi dịch vụ | Client cũ không tương thích Rules mới; client mới chưa có transport production. Không phát hành riêng một phía |
| Admin xác nhận/hoàn thành | Đã chuyển sang backend; lịch legacy thiếu timestamp/thời lượng sẽ bị chặn bảo thủ. 48 bản ghi hiện có đủ hai trường, vẫn cần rehearsal |
| Voucher/thông báo | createBooking ghi cùng transaction; thưởng tích lũy sau hoàn thành vẫn do client admin gọi riêng nên có thể hoàn thành thành công nhưng thưởng thất bại. Cần đối soát/retry idempotent hoặc chuyển side effect sang backend, không hứa atomic hiện tại |
| VNPAY/Worker | Source Worker ghi payment/status bằng REST với service account và precondition; không dùng employee_days. Rules không chặn Admin/IAM writer. Cần test callback trùng, callback đến muộn, hủy/hoàn thành cạnh tranh; giữ hoặc drain IPN khi bảo trì, không làm thất lạc thanh toán |
| Đăng nhập | Khách không có staff link vẫn là khách; Rules role-check phải sẵn sàng. UID/admin cũ không tự đổi. Tài khoản bị tắt vẫn cần kiểm tra SDK/rules/backend và hành vi token cũ |
| Dữ liệu lịch sử | Không tính lại tiền cũ theo catalog mới. Báo cáo hoàn thành/tiền đã thu, start/finish nhân viên và ledger 2B/2C chưa được triển khai |
| Hiệu năng | Backend còn đọc toàn bộ lịch/ca theo employee hoặc salon rồi lọc ngày trong RAM; polling availability 5s, danh sách thợ 10s. Cần đo chi phí/độ trễ khi dữ liệu tăng, giới hạn tải trước vận hành rộng |
| Retry | requestId hiện giữ trong bộ nhớ UI/service; cần quyết định phục hồi sau refresh/app kill, không khẳng định đã có durable outbox |

## 6. Trình tự triển khai đề nghị để duyệt

1. Duyệt **sửa mã cục bộ/staging trước**, không duyệt deploy commit f7cb96e trực
   tiếp. Chuẩn bị transport production, gate server/client, lỗi/retry và các vấn
   đề Rules/voucher nêu trên. Không mở rộng 2B/2C trong bước này.
2. Chủ dự án duyệt billing/chi phí, bật các API cần thiết và chọn identity/runtime
   và nơi lưu backup. Không tự nâng quyền. Kiểm kê Functions đang có sau khi API
   khả dụng; giữ nguyên tên/tài nguyên ngoài phạm vi.
3. Rehearsal trên project staging riêng: Rules, index READY, service catalog,
   các schema legacy đã khử thông tin cá nhân, Web/Android. Không mang production
   Auth export hoặc IPN/secret thật sang staging.
4. Chốt manifest dữ liệu (6 dịch vụ, UID mapping, lịch tương lai), runtime config,
   checksum của Rules/index/source và rollback package. Đưa thay đổi cụ thể để
   duyệt lần cuối trước bất kỳ thao tác ghi/triển khai thật.
5. Trong cửa sổ bảo trì có giám sát: đóng writer cũ và mới/ép cập nhật client;
   drain/đối soát callback thanh toán. Sao lưu T0 và kiểm tra bản sao dùng được.
6. Triển khai index/Functions có gate đóng; kiểm tra sức khỏe không tạo booking.
   Ghi dữ liệu được duyệt có precondition và before-image; triển khai Rules/app
   tương thích trong cùng cửa sổ. Không bật backend guarded writes trong khi vẫn
   cho legacy client ghi trực tiếp.
7. Canary với nhân viên/admin được chọn và phương thức trả sau được duyệt; kiểm
   tra audit, slots, receipts, không trùng ca/booking. Đối soát thanh toán riêng
   trước khi mở pay_now. Chỉ mở toàn bộ khi đạt cổng kiểm thử và có người duyệt.

## 7. Sao lưu trước khi ghi thật — mới là kế hoạch

- Sau khi chủ dự án bật billing/duyệt nơi lưu, backup/export **toàn database**,
  gồm subcollections, vouchers, payment_orders, settings, notifications/chats và
  các collection mới; không chỉ 8 collection đã khảo sát. Lưu riêng Rules online,
  release/ruleset ID/hash, index/fieldOverrides/TTL, source/config Functions,
  binary Web/Android cũ và cấu hình Worker không có secret trong Git.
- Chọn Cloud Storage bucket riêng tại vùng phù hợp, không public, quyền tối
  thiểu, retention được duyệt. Export khi writer đã dừng hoặc dùng snapshot/PITR
  phù hợp; export thông thường có thể bao gồm thay đổi trong lúc chạy và không
  chứa index definitions. Ghi operation ID, thời điểm T0, checksum/manifest,
  chờ DONE rồi kiểm thử đọc/khôi phục ở nơi cô lập.
  [Export/import](https://firebase.google.com/docs/firestore/manage-data/export-import).
- Đề nghị backup hằng ngày, retention 14 ngày và PITR 7 ngày sau khi duyệt chi
  phí; chưa bật. Scheduled backup là bản nhất quán gồm dữ liệu/index và khôi phục
  sang database mới; Rules/Auth/Storage không thay thế bằng backup Firestore.
  [Scheduled backups](https://firebase.google.com/docs/firestore/backups),
  [PITR](https://firebase.google.com/docs/firestore/use-pitr).
- Auth cần bản sao riêng trước provisioning/đổi tài khoản: bảo toàn UID/provider,
  disabled/emailVerified và các cấu hình phục hồi cần thiết. Nếu làm full export
  chứa hash thì mã hóa và lưu kho bí mật do chủ dự án kiểm soát; không log, không
  gửi trong chat/Git. Lần này chỉ đọc metadata qua field mask, chưa export Auth.
  [Auth export/import](https://firebase.google.com/docs/cli/auth).
- Ảnh Storage và secret Worker được sao lưu/version hóa riêng theo quyền và nơi
  lưu được chủ dự án duyệt; chưa đọc hoặc sao chép giá trị secret Worker.

## 8. Khôi phục và điều kiện dừng

Đề xuất mục tiêu cần chủ dự án chốt: rollback cấu hình trong 30 phút nếu diễn tập
đạt; không mất ghi đã được xác nhận trong cửa sổ bảo trì. Chưa đo RTO/RPO, không
cam kết chỉ dựa vào file export hoặc kết quả Emulator.

1. Dừng mở rộng khi login lỗi, booking không tạo/hủy được, có overbooking, dữ liệu
   link sai, index chưa READY hoặc thanh toán lệch. Đóng server mutation gate và
   writer cũ; giữ đọc dữ liệu và xử lý/đối soát IPN theo runbook đã duyệt.
2. Ưu tiên rollback mã/config bằng gói client cũ và Rules **thực sự online ở T0**,
   không lấy Rules ở commit 3598f5c/f7cb96e làm giả định baseline. Chỉ mở legacy
   writer khi backend mới không còn ghi và đã đối soát slot/booking.
3. Không xóa Functions, dự án, database, tài khoản, documents, guards/receipts hay
   ca vừa tạo. Giữ code trước đó hoặc gate đóng; dữ liệu mới được giữ làm chứng
   từ. Link sai: inactive + tắt portal có kiểm soát, giữ link/audit để sửa theo
   phương án được duyệt; không tự unlink hoặc đổi UID.
4. Không import đè toàn production như nút Undo. Import ghi đè document trùng ID
   và giữ các document không có trong export; có thể làm mất ghi sau T0 và không
   xóa các document mới. Restore sang database/project cô lập trước, so sánh IDs,
   trạng thái, tổng tiền, audit và các thay đổi sau T0; lập danh sách phục hồi
   chọn lọc với precondition/updateTime, duyệt trước khi apply.
5. Ca đã có khách không được hủy chỉ để rollback. Giữ lịch khách còn hiệu lực;
   điều chỉnh ca sau đối chiếu. Nếu cần ngừng dịch vụ mới, chỉ đổi isActive sau
   duyệt, không xóa snapshot giá/catalog hoặc lịch sử booking.
6. Nếu rollback source không phù hợp schema v2 hoặc slot IDs mới, giữ chế độ
   bảo trì và sửa tiến tới; không mở ứng dụng cũ ghi trên dữ liệu chưa đối soát.

## 9. Cổng kiểm thử trước quyết định triển khai thật

- Không còn URL localhost/demo hoặc cờ chặn Emulator trong luồng production;
  Emulator vẫn tách biệt. Test token sai project, hết hạn, disabled, email chưa
  xác minh, quyền admin bị rút và link inactive/cross-branch.
- Legacy 48 bookings: xem lịch sử/giá/payment giữ nguyên; xử lý trường thiếu theo
  chính sách đã duyệt. Tạo ca, OFF, nhiều ô, stale revision, A/B đủ bốn tổ hợp;
  booking cạnh tranh với save/swap/cancel chỉ có trạng thái hợp lệ.
- Production index READY, Web reload giữ dữ liệu, Android cùng hành vi, tải/chi
  phí polling đo được. Không dùng HTTP/VM thay bằng chứng UI Web.
- Payment sandbox isolated: callback hợp lệ/trùng/muộn/cạnh tranh; refund/manual
  cancellation rõ ràng; thưởng voucher/thông báo không trùng và phục hồi được.
- Diễn tập backup/restore cô lập; checksum và before-image đầy đủ; số tài khoản,
  UIDs, lịch hẹn/slot/audit khớp. Có người chịu trách nhiệm và chấp thuận cutover.

34/34 backend/Rules và 18/18 Flutter, analyze sạch, Web demo của bản f7cb96e là
bằng chứng cục bộ trước đó; **chưa phải chứng nhận staging/production**. Lần rà
soát này không chạy luồng ghi hay thanh toán nào trên Firebase thật.
