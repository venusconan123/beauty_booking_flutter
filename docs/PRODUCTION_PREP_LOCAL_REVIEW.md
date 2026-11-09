# Hoàn tất chuẩn bị production cục bộ — công tắc ghi, voucher, thanh toán

Ngày cập nhật: 09/11/2026. Nhánh `codex/staff-phase-one`, baseline `f7cb96e`.
Bản này tổng hợp thay đổi được rà soát để commit/push theo yêu cầu sau kiểm thử
Web; kết quả trực tiếp tại [WEB_EMULATOR_VERIFICATION.md](WEB_EMULATOR_VERIFICATION.md).
Giữ riêng file kiểm tra quyền có trước. Không gọi thao tác ghi Firebase thật, không bật billing/API, không đổi IAM,
tạo tài khoản thật hoặc deploy Firebase/Worker. Không thay lịch thật ngày 02/11.

## Thay đổi đã có trong working tree

- SchedulingService giữ callable protocol `{data: ...}`, Firebase ID token,
  timeout/đóng HTTP client, requestId và receipt hiện có. Emulator đi về demo
  localhost; production đi HTTPS `asia-southeast1-<Firebase project>.cloudfunctions.net`.
  Project lấy từ Firebase app đã khởi tạo; tên callable được allowlist. Không bật
  cờ Emulator để lách production. Chưa thêm cloud_functions/App Check SDK.
- Đặt/hủy/đổi dịch vụ, phân ca và liên kết tài khoản dùng chung transport này.
  Màn hình liên kết không còn khóa theo môi trường; backend vẫn xác minh admin,
  Auth tồn tại/verified/enabled và hai chiều link. Không có chức năng tạo Auth user.
  Danh sách thợ đặt lịch ở production cũng dùng backend lọc ca, không còn đường
  fallback chọn mọi thợ active bất kể ca.
- Thêm `requireWrites` trong transaction của tất cả mutation phân ca, booking,
  liên kết/tắt nhân viên và dọn slot. Production thiếu config hoặc protocol sai
  sẽ đóng ghi. Cấu hình thay đổi cạnh tranh với transaction cũng được Firestore
  đọc/khóa lại; không chỉ là ẩn nút ở UI.
- Worker có công tắc riêng để ngừng **tạo giao dịch mới**, trong khi IPN đã có vẫn
  được tiếp nhận để đối soát. Thiếu config mặc định đóng tạo thanh toán.
- Rules cục bộ bỏ đường customer tự cập nhật voucher quota, tiêu thụ voucher cá
  nhân hoặc tạo redemption. Backend tạo booking/tiêu thụ mã trong một transaction.
  Slot chỉ owner/admin đọc; writes vẫn chỉ backend. Quyền admin quản lý catalog
  voucher giữ nguyên. Đây vẫn là Rules prototype, không phải đánh giá toàn app.
- Thưởng tích lũy của luồng **admin hoàn thành hiện có** được chuyển từ bước
  Flutter riêng sang transaction backend cùng status, slots, notification/audit
  và receipt. Giữ ID voucher cũ theo booking/milestone; không cấp lại khi hoàn
  thành lặp. Không triển khai workflow nhân viên 2B hoặc ledger/thống kê 2C.

## Công tắc cần duyệt trước ghi thật

Document `app_settings/scheduling_v2` được đề xuất tạo với:

```json
{
  "protocolVersion": 2,
  "bookingWritesEnabled": false,
  "rosterWritesEnabled": false,
  "staffWritesEnabled": false,
  "paymentCreationEnabled": false
}
```

Đây chỉ là preview, **chưa tạo trên Firebase thật**. Sau sao lưu và duyệt, có thể
mở roster/staff để chuẩn bị danh sách, vẫn đóng booking/payment; chỉ mở booking
sau cutover Rules/client/Worker. Mở tạo thanh toán là bước riêng sau đối soát.
Không thay config này tự động lúc module load. Chỉ demo project + Firestore host
loopback mới được mở mặc định khi thiếu document để giữ workflow Emulator cũ.

## Callback thanh toán đã sửa

- Giữ kiểm tra chữ ký HMAC, merchant, số tiền, chủ booking, orderId và trạng thái
  payment/order. Không tin trang return thay cho IPN.
- Cùng một REST commit có preconditions trên booking, order và employee/day guard;
  kèm audit xác định theo order và notification. Nó tham gia cùng protocol guard
  với backend booking/phân ca, không chỉ dựa vào booking updateTime.
- Pending hợp lệ có thể chuyển confirmed khi nhận tiền. Cancelled/completed
  **không trở lại confirmed**. Kết quả paid vẫn được lưu; thêm requiresReview,
  và refundRequired nếu lịch đã hủy. Admin hủy lịch đã paid cũng đặt refundRequired.
- Callback lặp đọc order paid và trả trạng thái đã xử lý; không ghi lại guard,
  audit hoặc tạo notification trùng. Hai callback đồng thời không thể cùng commit.
- Nếu callback đọc trước rồi hủy lịch thắng transaction, commit callback thất bại
  precondition; lần IPN retry ghi paid để đối soát nhưng giữ cancelled, slots
  released. Nếu nhận tiền thắng trước, hủy sau vẫn giữ paid và đánh dấu cần hoàn.
- Các cờ đối soát **không thực hiện hoàn tiền**. Chưa có UI/quy trình hoàn tiền tự
  động hoặc ledger doanh thu mới. Không tuyên bố đã hỗ trợ VNPAY live.

## Kết quả kiểm thử

| Kiểm tra | Kết quả | Bằng chứng/phạm vi |
| --- | --- | --- |
| Backend + Rules + callable HTTP + callback | 40/40 đạt ở vòng cuối | Emulator 8180/9199/5101, demo project; gồm kiểm tra slots vẫn released sau callback/hủy cạnh tranh |
| Công tắc | Đạt | Thiếu config production đóng ghi bằng unit stub không nối cloud; paused từ chối cả admin, không thay dữ liệu; mở lại thao tác được |
| Voucher | Đạt | Replay booking không tiêu thụ hai lần; customer không dùng booking legacy để tăng quota/forge redemption; completion/retry không thưởng trùng |
| Callback hợp lệ/lặp | Đạt | Chữ ký test thật với secret fixture; paid một lần, guard tăng đúng một lần khi hai callback đồng thời |
| Callback cạnh tranh hủy | Đạt | Ép hủy xen giữa read và commit; thêm Promise.allSettled callback/cancel; retry giữ paid + cancelled/refundRequired, không phục hồi slot |
| Sai merchant/số tiền/chữ ký | Đạt | Không đổi booking/order; test chữ ký thiếu tại Worker unit suite |
| Bảo toàn legacy | Đạt | Fixture local ngày 02/11 thiếu schemaVersion/workShiftId vẫn nguyên dữ liệu sau availability và booking mới, không tự đổi trạng thái/giá |
| Flutter | 20/20 đạt | Gồm mock HTTPS đúng project/header/payload/requestId; không gửi request lên cloud |
| Analyze | Đạt | Không có vấn đề |
| Worker unit | 9/9 đạt | Gồm công tắc tạo payment mặc định đóng, terminal status không được hồi sinh |
| Build Web production | Đạt | Build release cục bộ, không mở bản production hoặc gọi Firebase thật |

Callback integration dùng Firestore Emulator thật; Google OAuth được stub,
Firestore URL chỉ được phép chuyển tới demo localhost. RSA key/merchant/secret
chỉ là fixture sinh cục bộ, không đọc hoặc dùng khóa/tài khoản cloud thật.
Đây không phải kiểm thử trực tiếp VNPAY hay triển khai Cloudflare thật.

Logs nằm ở `.dart_tool/production-prep-*`, bị Git bỏ qua. Không đưa log, build,
RSA fixture hoặc dữ liệu Emulator vào commit. Các kiểm thử không reset dữ liệu
demo tương tác ở 8080/9099 và không chạm dữ liệu thật.

## Phần chưa xác minh, vẫn cần trước production

- Chưa thử HTTPS thực tế trên staging/Cloud Run, IAM runtime, billing/API, CORS
  trình duyệt production hoặc App Check. Unit mock/build không thay bằng chứng này.
- Đã thử trực tiếp Web mới trên trình duyệt trong ứng dụng: phân ca/đổi A-B,
  đặt/hủy có voucher, nhân viên xem lịch và chặn ghi. Chi tiết và giới hạn ở
  WEB_EMULATOR_VERIFICATION.md. Chưa test Chrome native/Android/điện thoại thật
  cho transport mới; không dùng HTTP/VM để kết luận các nền tảng này đã đạt.
- Chưa thử IPN thật, chính sách bank retry, số tiền thực, cấu hình/secret Worker
  online, trường hợp bank gửi thành công sau order đã failed/đã thay orderId hoặc
  quy trình hoàn tiền. Không mở pay_now/live trước khi đối soát các trường hợp này.
- Client cũ ghi booking trực tiếp vẫn không tương thích Rules mới; cần cửa sổ
  bảo trì/cập nhật bắt buộc. Gate mới không ngăn legacy writer đang được Rules
  online cho phép. Worker mới cũng cần được duyệt/deploy đồng bộ trước mở ghi.
- Chưa diễn tập restore production snapshot, chưa tạo backup/PITR. Baseline cloud
  vẫn là kết quả đọc trước đó: billing/API tắt, chưa có ca/link; không đọc lại
  hoặc sửa lịch thật ngày 02/11 trong lượt triển khai cục bộ này.
- Các đường reports/support có schema rộng vẫn cần đợt hardening riêng; requestId
  UI chưa có durable outbox sau refresh/app kill; tải polling và quét lịch sử chưa
  đo ở quy mô production. Không khẳng định toàn ứng dụng đã production-ready.

## Cập nhật bản xem trước triển khai và dữ liệu

`firebase.production.preview.json` vẫn chỉ trỏ Functions + Firestore candidate,
không triển khai Worker/Storage/Hosting. Hai module nội bộ mới `write_control.js`
và `loyalty.js` không thêm callable exports; tổng 12 exports giữ tên cũ.
`cloudflare_worker/src/index.js` là gói thay đổi riêng cần duyệt, không chạy
wrangler deploy trong lượt này. Index composite vẫn chỉ salonId/dateKey cho roster.

`production-preview/data-change-preview.json` bổ sung control document mặc định
đóng và các trường do thao tác sau này tạo. 6 service creates vẫn cần duyệt giá;
UID mapping và danh sách ca còn trống, chưa tự chọn. Không có automatic update
cho 48 booking cũ, không có thao tác xóa, đổi Auth UID/password hoặc đổi lịch 02/11.

## Sao lưu và khôi phục

Giữ kế hoạch trong FIREBASE_PRODUCTION_READINESS: backup toàn database và các
subcollections, Auth riêng mã hóa khi thực sự cần provisioning, Rules/index/config
và Worker version; kiểm tra backup hoàn tất và restore cô lập trước apply thật.
Chưa thực hiện export/backup production, không dùng export Emulator thay thế.

Thứ tự khôi phục bổ sung: đóng booking/roster/staff và paymentCreation gates,
drain IPN đang chạy; giữ ghi nhận tiền để đối soát và không phục hồi lịch kết thúc.
Rollback code/Rules/Worker chỉ sau đối chiếu schema/slot; không mở legacy writer
cùng lúc backend mới còn ghi. Không reset guard/receipt/audit, không xóa ca/link,
không import đè database như Undo và không hạ status paid thành unpaid. Phục hồi
chọn lọc từ bản restore cô lập phải giữ các giao dịch hợp lệ sau T0, có precondition
và duyệt riêng. Link sai chỉ inactive + xử lý portal theo phương án duyệt, không
unlink/xóa tài khoản. Lịch 02/11 do chủ dự án đối chiếu, không nằm trong apply.
