# Bản duyệt triển khai Firebase — commit 5084af0

> Theo yêu cầu mới về quy mô khóa luận, phương án tối thiểu hiện hành là
> [FIREBASE_THESIS_MINIMAL_PLAN.md](FIREBASE_THESIS_MINIMAL_PLAN.md).
> Yêu cầu tạo project staging và dự trù pilot ở dưới là phương án trước đó;
> không tự áp dụng cho đợt demo ít người. Báo cáo này giữ làm hồ sơ của 5084af0.

Ngày lập: 09/11/2026. Mã được đánh giá: `5084af0caeeb38c726592576273f7f40f53f397f`,
nhánh `codex/staff-phase-one`. **Trạng thái: CHƯA DUYỆT, CHƯA SẴN SÀNG đưa vào
production; có thể duyệt một đợt chuẩn bị/kiểm thử staging riêng.** Báo cáo này
thay kết luận về mã nguồn ở bản baseline f7cb96e, không thay lịch sử kiểm tra cloud.
Không kèm script apply hoặc lệnh deploy có thể chạy nhầm. Lượt cập nhật này chỉ
đọc source/tài liệu giá chính thức và sửa tài liệu cục bộ; không truy cập lại
dữ liệu cloud, tạo tài nguyên, bật billing/API, đổi IAM, deploy, commit hay push.

## 1. Bằng chứng đã có và giới hạn

| Hạng mục | Đã đạt ở 5084af0 | Chưa chứng minh |
| --- | --- | --- |
| Web Emulator | Admin phân ca, A/B, reload; khách đặt/hủy voucher; staff xem đúng lịch/ca chỉ đọc; đóng ghi hiện lỗi và hết chờ | HTTPS cloud, Chrome native, Android/thiết bị thật |
| Backend/Rules | 40/40; quyền, trùng xuyên chi nhánh, bốn tổ hợp đổi A/B, cạnh tranh ghi, voucher và IPN/hủy | IAM runtime, index cloud, quota/độ trễ/chi phí thực tế |
| Flutter/Worker | Flutter 20/20, Worker 9/9, analyze sạch, build release cục bộ | VNPAY sandbox qua Worker staging thật, IPN/live/refund |
| Transport/gate | HTTPS theo Firebase project đã khởi tạo, 12 callable; gate đóng mặc định ngoài demo; voucher completion atomic, callback không phục hồi lịch đã hủy | Khả năng triển khai và hoạt động trên project cloud riêng |

Chi tiết UI: [WEB_EMULATOR_VERIFICATION.md](WEB_EMULATOR_VERIFICATION.md).
Thống kê/ledger 2C, nhân viên bắt đầu/hoàn thành phục vụ 2B **chưa có**; giao diện
thống kê còn khung. Phát hành này không được giới thiệu là đã hỗ trợ các mục đó.

Baseline chỉ đọc cloud trước đây (09/11, xem manifest): project `men-hair-booking`,
Firestore Standard Native `(default)` ở `asia-southeast1`; billing chưa bật,
Functions API trả SERVICE_DISABLED nên chưa kiểm kê được Functions. 23 quyền
project được hỏi đều có nhưng chưa kiểm tra billing-account/bucket/runtime-SA.
Có 15 nhân viên, 6 Auth (4 verified), 48 lịch (26 hủy, 21 hoàn thành, 1 xác nhận),
1 service, chưa có ca/link; không thấy composite index/backup/schedule, PITR tắt.
Đây là quan sát lịch sử, không phải cam kết trạng thái hiện tại. **Không tự xử lý
lịch 02/11/2026 09:30–10:30 salon_01, pay_later/unpaid**; chủ dự án đối chiếu riêng.

## 2. Các điểm còn chặn và điều kiện gỡ chặn

| Mã | Điểm chặn | Bằng chứng cần có trước mở production |
| --- | --- | --- |
| B1 | Billing/API, inventory Functions và service agents/runtime chưa xác minh đủ | Chủ dự án duyệt chi phí và cấu hình; đọc lại inventory, kiểm tra quyền theo từng identity; không tự nâng quyền |
| B2 | Chưa có cấu hình staging cô lập | Project/app/Firestore/Auth/Worker riêng, token và endpoint đều đúng staging; chặn đường mặc định trỏ production |
| B3 | Legacy writer và Rules không tương thích | Cửa sổ bảo trì/ép cập nhật khả thi; không còn client/Worker cũ ghi bypass guard; Rules mới và client mới chuyển cùng đợt |
| B4 | Chưa có backup T0 và diễn tập restore | Backup đầy đủ, kiểm tra được và diễn tập cô lập; có người phụ trách, RTO/RPO được đo/chấp thuận |
| B5 | Chưa duyệt catalog, UID mapping, ca thực tế và tên/giờ chi nhánh | Danh sách cụ thể, before-image/precondition, người chịu trách nhiệm xác nhận; không đoán UID từ tên |
| B6 | Hiệu năng/chi phí chưa đo; query quét lịch sử, polling 5s/10s | Đo trên dữ liệu tích lũy, ngưỡng tải/chi phí; sửa query/polling cục bộ nếu vượt và kiểm thử lại, không tự xóa lịch sử |
| B7 | CORS/invoker, revoked/disabled token, App Check chưa thử cloud | Test quyền và token thật staging; quyết định App Check theo client thực tế, không bật enforce khi client chưa gửi token |
| B8 | IPN/Worker thực tế, failed→paid, đổi orderId, refund chưa xác minh | Đối soát sandbox, runbook retry/refund; giữ paymentCreation đóng nếu chưa đạt; không coi cờ refundRequired là đã hoàn tiền |
| B9 | Rules ngoài lịch làm còn schema reports/support rộng | Rà soát riêng và chấp thuận rủi ro hoặc bản hardening đã kiểm thử trước phát hành rộng |

Gate là công tắc cho mutation nghiệp vụ đã bọc `requireWrites`, **không phải
khóa ghi toàn database**: cập nhật `users.phone/updatedAt` xảy ra trước tạo
booking; quản lý catalog/voucher/kiểu tóc và một số profile/chat vẫn có đường
client riêng. Admin mở trang nhân viên/kiểu tóc có `ensureDefaults`; phải kiểm
tra marker/catalog, không dùng thao tác mở trang để seed dữ liệu thật. Worker
đọc paymentCreation gate trước tạo order, không phải transaction fence cho
mọi giao dịch đang chạy. Bảo trì phải dừng/drain writer cũ và request đang chạy,
không chỉ đổi bốn cờ hoặc ẩn nút.

## 3. Cấu hình, billing, API và quyền cần duyệt

Cloud Functions deployment yêu cầu **Blaze**; đây là thanh toán theo sử dụng,
không phải mua gói có giá cố định. Nâng billing của staging và production là hai
quyết định riêng. [Điều kiện Functions](https://firebase.google.com/docs/functions/get-started).

| Thành phần | Đề xuất / việc cần kiểm tra sau khi được duyệt |
| --- | --- |
| Region/runtime | Functions Gen 2, Node 22, `asia-southeast1`, codebase `staff`; Firestore Standard Native cùng vùng, không chuyển vùng DB hiện có |
| API triển khai | Kiểm kê rồi bật phần còn thiếu: `cloudfunctions.googleapis.com`, `run.googleapis.com`, `cloudbuild.googleapis.com`, `artifactregistry.googleapis.com`; kiểm tra `logging.googleapis.com`, `storage.googleapis.com`, `serviceusage.googleapis.com` phục vụ triển khai/backup |
| API nghiệp vụ | Kiểm tra `firestore.googleapis.com`, `identitytoolkit.googleapis.com`, `securetoken.googleapis.com`, `firebaserules.googleapis.com`; không bật hàng loạt API ngoài nhu cầu |
| API có điều kiện | Secret Manager/App Check nếu chọn dùng; hiện source Functions không tham chiếu Secret Manager. Không có trigger Eventarc/PubSub/Cloud Scheduler trong 12 exports, không tự tạo các dịch vụ này |
| Billing/IAM | Người gắn billing cần quyền billing-account/project thích hợp; deployer cần deploy/build/upload, actAs đúng SA. Runtime cần đọc/ghi Firestore và đọc Auth cho link/identity; build/service agents cần quyền build/image/source. Xác minh resource cụ thể, không suy từ 23 quyền CLI; mọi quyền thiếu phải báo chủ dự án |
| Invoker/Auth | Callable public ở tầng HTTP nếu cần để nhận Firebase ID token, vẫn xác thực và phân quyền trong callable; Firebase token không thay IAM ID token. Kiểm tra chính sách tổ chức và CORS OPTIONS/POST trên staging trước khi đề nghị quyền cần thiết, không tự mở quyền |
| Giới hạn chạy | Source 5084af0 chỉ pin region, chưa pin CPU/memory/maxInstances. Đề xuất staging minInstances=0, maxInstances=2/function, 256MiB, 1 CPU, request timeout phù hợp; cần patch cấu hình được duyệt và đo thực tế. 12 Functions có giới hạn riêng, không phải tổng 2 instances |
| Client | Emulator=false ở cloud; sinh cấu hình FlutterFire **staging riêng** trước khi mở app. `firebase_options.dart` hiện trỏ project thật, không có selector staging sẵn. Android cần app/config riêng. Không ghi đè cấu hình production hoặc dùng cờ Emulator để giả staging |
| Worker | Worker staging tên/URL riêng; bắt buộc override `VNPAY_API_BASE_URL`, vì default hiện là Worker production. Bốn cấu hình: `VNP_TMN_CODE`, `VNP_HASH_SECRET`, `FIREBASE_WEB_API_KEY`, `FIREBASE_SERVICE_ACCOUNT_JSON`; chỉ merchant sandbox + identity/project staging, giữ secret ngoài Git/log. Không sao chép secret thật sang staging |
| Index | `work_shifts`: `salonId ASC, dateKey ASC`, COLLECTION; giữ các index online khác. Đợi READY; Emulator không xác nhận index cloud. Không xóa index/export ngoài phạm vi |
| Backup/monitor | Bucket backup cùng vùng, nơi lưu riêng có quyền/retention được duyệt; snapshot Rules/index/config/client/Worker. Đề xuất backup ngày giữ 14 ngày, PITR 7 ngày và delete protection, đều cần duyệt riêng |

API build/runtime: [Cloud Run functions deploy](https://docs.cloud.google.com/run/docs/deploy-functions),
[build identities](https://docs.cloud.google.com/functions/docs/building).
Callable transport: [protocol](https://firebase.google.com/docs/functions/callable-reference).

Gói Firebase dự kiến: `firebase.production.preview.json` chỉ Functions +
Firestore Rules/index; không Hosting/Storage Rules/Worker. 12 exports giữ tên:
`linkStaffAccount`, `setStaffAccountActive`, `saveRoster`, `saveShifts`,
`cancelShift`, `swapShifts`, `createBooking`, `updateBookingServices`,
`changeBookingStatus`, `getAvailability`, `listBookableStaff`, `releaseStaleSlots`.
Module load không migrate/seed. Worker là bản triển khai riêng phải phối hợp.

## 4. Chi phí dự kiến — để duyệt dự trù, chưa phải báo giá

USD, chưa VAT, chưa chuyển tỷ giá. Giá được tra tài liệu chính thức ngày lập;
**chưa có usage/bill cloud thực đo**. Tổng gồm Firestore reads/writes/index/storage,
Functions CPU/RAM/request/network, build/images, logs, backup/PITR/restore/GCS và
Worker. Chưa bao gồm phí VNPAY/merchant, SMS, tên miền, hosting/ảnh hoặc công
triển khai. Chọn email/password trong staging, không thử SMS có phí.

Firestore có mức miễn phí cho một DB/project: 50.000 reads/ngày, 20.000 writes/ngày,
1GiB lưu trữ; backup/PITR/restore không nằm trong miễn phí. Giá phụ thuộc vùng,
phải chọn Singapore trong calculator trước duyệt ngân sách thực thi. Không lấy
bảng mặc định Iowa làm giá Singapore. [Firestore pricing](https://cloud.google.com/firestore/pricing).

Gen 2 dùng mô hình Cloud Run; mức miễn phí request-based tham chiếu là 2 triệu
requests, 180.000 vCPU-s và 360.000 GiB-s/tháng, dùng chung theo billing account,
không nhân 12 Functions hay hai project; free discount theo giá Tier 1, không
bảo đảm cả staging và production đều 0 đồng. [Cloud Run pricing](https://cloud.google.com/run/pricing).
Build/artifact storage/log/network tính riêng; giữ minInstances=0 để tránh giữ
instance ấm chưa cần. Cleanup image cần chính sách giữ đủ bản rollback, không
tự bật xóa image. [Quản lý Functions](https://firebase.google.com/docs/functions/manage-functions).

**Mô hình dự trù tự chọn**, không phải đơn giá nhà cung cấp: lấy 0,10 USD/100.000
reads, 0,30 USD/100.000 writes để tính nhạy cảm, chưa trừ free quota. Dùng hệ số
này cho dễ thấy tác động quét lịch sử; trước cấp billing phải thay bằng SKU
Singapore chính thức và usage staging, không xem đây là trần chi tiêu.

`N_calls = số phiên đồng thời trung bình × giờ mở/ngày × số ngày × 360` cho
polling 10s; `N_reads ≈ N_calls × D`, D là số documents đọc thực tế mỗi lần,
gồm cả ca lịch sử và hồ sơ. Availability 5s và transaction/retry có chi phí thêm.

| Kịch bản giả định | Lượng đọc danh sách thợ | Dự trù đọc theo mô hình | Dự trù tổng cần duyệt |
| --- | --- | --- | --- |
| Staging: 5 phiên × 1h × 5 ngày; D=100 | 9.000 calls, 0,9 triệu reads | 0,90 USD | Khoảng 5–20 USD cho đợt thử ngắn, gồm dự phòng build/backup/Worker; không phải phí hàng tháng bắt buộc |
| Pilot: 10 phiên × 3h × 30 ngày; D=100 | 324.000 calls, 32,4 triệu reads | 32,40 USD | Dự trù 50–80 USD/tháng; chỉ hợp lệ nếu tải thực tương đương và không giữ instance ấm |
| Dữ liệu/tải tăng: 30 phiên × 8h × 30 ngày; D=1.000 | 2,592 triệu calls, 2,592 tỷ reads | 2.592 USD chỉ phần này | Không duyệt mở rộng với query hiện tại; tổng còn cao hơn, cần sửa/đo lại |

Đây là suy tính từ source, không phải dự báo số khách. Backend hiện đọc toàn bộ
ca theo salon rồi lọc ngày; `loadDay` cũng đọc ca/booking lịch sử theo nhân viên.
Không suy 48 bookings hiện tại là hóa đơn luôn nhỏ. Staging cần dataset có lịch
sử lớn để đo D và tốc độ, rồi chọn ngân sách; maxInstances chỉ hạn chế tài nguyên
đồng thời, không là trần hóa đơn Firestore. Managed export tính reads/import
tính writes và GCS riêng. [Export/import billing](https://firebase.google.com/docs/firestore/manage-data/export-import).

Worker có lựa chọn Free giới hạn và Paid khởi điểm khoảng 5 USD/tháng; RSA/OAuth
và CPU limit phải thử staging trước chọn gói, khoản này riêng Firebase.
[Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/).

Đề xuất cảnh báo staging 5/10/20 USD và production 25/50/80 USD theo ngân sách
được duyệt; chủ dự án nhận cảnh báo và đóng ghi mới khi cần, giữ đối soát tiền.
Alerts-only budget không tự dừng phí. Tài liệu hiện còn mô tả spend-cap cho một
số dịch vụ: phải kiểm tra khả dụng/phạm vi trước dùng; không mặc định đó là cap
Firestore hay tự bật gây ngắt dịch vụ. [Budget guidance](https://firebase.google.com/docs/projects/billing/avoid-surprise-bills).

## 5. Bản xem trước dữ liệu thêm/sửa

Manifest máy đọc: [data-change-preview.json](production-preview/data-change-preview.json),
`approved=false`, `executed=false`. Tất cả đường dẫn dưới đây là đề xuất,
không phải dữ liệu đã ghi. Không import dữ liệu/tài khoản demo vào production.

| Nhóm | Thay đổi sau khi được duyệt | Điều kiện/bảo toàn |
| --- | --- | --- |
| Control | Tạo `app_settings/scheduling_v2`, protocolVersion=2, cả bookingWritesEnabled/rosterWritesEnabled/staffWritesEnabled/paymentCreationEnabled=false | Create-if-absent, re-read chống drift; mở từng gate là quyết định sau |
| Catalog | Tạo 6 service thiếu: cắt 80.000đ/30p, gội 30.000đ/20p, tạo kiểu 50.000đ/30p, uốn 250.000đ/120p, nhuộm 300.000đ/150p, da 100.000đ/45p | Giá/thời lượng cần duyệt; không ghi đè combo hoặc service mới do người khác thêm |
| Staff link | Mỗi mapping được duyệt tạo `staff_accounts/{uid}` và `employee_accounts/{employeeId}`, active/timestamps/audit | Danh sách hiện trống; Auth đã có/enabled/verified, nhân viên active, không link trùng; không tạo Auth, đổi password/UID hoặc thay 15 hồ sơ |
| Ca | Admin tạo ca/OFF được duyệt trong `work_shifts`, cập nhật revision/status khi phân lại/đổi/hủy mềm | Danh sách hiện trống; kiểm tra khách/trùng xuyên chi nhánh và 4 tổ hợp A/B; giữ lịch sử, không tự lấp tháng hoặc tạo ca quá khứ |
| Booking mới | `bookings`, `booking_slots`, `employee_days`, `schedule_operations`, `audit_events`, notifications; snapshot giá/dịch vụ và assignment | Backend transaction và requestId; thay đổi ca/booking chỉ qua backend; không migrate 48 lịch cũ hàng loạt |
| Voucher | Booking cập nhật usedCount/lastBookingId hoặc personal isUsed, tạo redemption; admin completion tạo thưởng/notification deterministic | Không hồi tố thưởng lịch cũ, không reset quota. Hủy lịch chưa hoàn lại lượt voucher trong bản này; Web đã chứng minh usedCount vẫn 1 sau hủy, cần chấp thuận chính sách này |
| Profile | Checkout cập nhật `users/{uid}.phone/updatedAt` trước gọi booking | Có thể xảy ra dù gate booking đóng; ghi nhận trong before/after và phạm vi bảo trì |
| Payment | Sau mở riêng: `payment_orders`, `bookings.payment/status`, day guard, audit/notification; paid muộn có requiresReview/refundRequired | Không hồi sinh cancelled/completed; không thực hiện refund, không ghi đè paid thành unpaid |

Giữ ID và giá/snapshot/thời điểm lịch sử, Auth/UID/admin hiện có; không tự thêm
schemaVersion/workShiftId hay payment.choice còn thiếu cho lịch cũ. Không xóa
project/database/tài khoản/document/index/Functions. Không thay trạng thái lịch
02/11. Tên chi nhánh 3 còn “mô phỏng”, giờ backend là 07:00–22:00: phải xác nhận
trước ghi tên/ca vào lịch thật. Loyalty admin hiện có giữ hành vi, không phải 2B/2C.

## 6. Đề xuất kiểm thử Firebase staging riêng — cần duyệt trước tạo

Firebase khuyến nghị tách project theo môi trường.
[Environment workflow](https://firebase.google.com/docs/projects/dev-workflows/overview-environments).
Đề xuất ID dạng `men-hair-booking-staging-<suffix>`; chưa chọn/check availability,
chưa tạo. Giữ project thật ngoài credentials/config của đợt thử.

1. Duyệt project name/owner, thời gian thử, ngân sách, billing account, quyền
   deploy/runtime và dữ liệu giả. Tạo project/app/Auth/DB/Worker staging chỉ sau
   duyệt; chốt region tương ứng, min/max và monitoring. Không dùng Auth export,
   PII hoặc service-account key production cho fixture.
2. Trong checkout/bản cấu hình staging riêng, thay toàn bộ FirebaseOptions/app
   registrations và Worker override trước build. Không đặt FIREBASE_EMULATORS=true.
   Kiểm tra build/config projectId/Auth audience/Functions URL/Worker SA project;
   nếu thiếu override hoặc còn endpoint production thì **dừng, không mở app**.
   Cấu hình selector staging và giới hạn runtime chưa được bổ sung trong 5084af0;
   đây là công việc chuẩn bị tiếp cần duyệt, báo cáo này không sửa runtime.
3. Triển khai đúng Rules/index/Functions candidate lên staging với gate đóng,
   đợi index READY. Seed dữ liệu giả được duyệt: 3 chi nhánh, 15 hồ sơ, catalog
   đủ 7 dịch vụ, tài khoản admin/staff/customer giả; `_catalog` đúng để tránh
   default seeding. Tạo link bằng UI; test inactive và ngăn link trùng. Fixture
   48 lịch theo các hình dạng legacy, gồm lịch 02/11 giả, không copy người thật.
4. Web Chrome native + trình duyệt xem trước, Android: login theo role; tạo
   nhiều ô/OFF/lặp, reload tháng; A/B hợp lệ/xung đột rõ người-ngày-giờ-chi nhánh;
   bốn tổ hợp lịch khách, ca xuyên chi nhánh; staff chỉ xem cùng chi nhánh/đúng
   lịch được giao. Token sai project, hết hạn, revoked/disabled, thiếu email
   verification, inactive/link sai và rút admin đều bị từ chối đúng.
5. Đặt/hủy voucher, hết quota, replay/requestId trùng, retry sau mất phản hồi;
   gate đóng cả trước và trong transaction, lỗi không treo UI. Cạnh tranh booking
   với sửa/đổi/hủy ca và hai khách cùng giờ: không có hai ghi vi phạm. Tạo legacy
   client thử ghi trực tiếp phải bị Rules chặn; lịch sử/giá cũ vẫn đúng.
6. Worker staging dùng sandbox riêng: IPN thật sandbox + ký giả lập cô lập,
   callback lặp/song song, muộn sau cancel/completed, tranh chấp cancel; audit/
   notification/guard một lần, slot không phục hồi. Bổ sung failed→paid, đổi
   orderId và quy trình đối soát/refund. Không đưa merchant live vào đợt này.
7. Đo tải có kiểm soát trên 1.000/10.000 ca/lịch giả, refresh/polling và nhiều
   phiên; đo read/write/request, retry/abort, latency p50/p95, CORS/cold start.
   Đề xuất mục tiêu cần chốt: p95 mutation <5s ở tải pilot, không UI chờ quá
   timeout mà mất khả năng retry, không duplicate; giữ ngâm 24–72h trong ngân
   sách. Nếu vượt chi phí/quota, dừng tải và đề xuất sửa, không mở production.
8. Diễn tập backup/restore staging sang DB/project cô lập và rollback version;
   so IDs/status/giá/slot/guard/receipt/link/voucher/audit. Đo RTO/RPO, giữ ghi
   mới sau T0. Tổng hợp bằng chứng UI + network/log đã bỏ token/PII + bill usage,
   failures/chưa test và manifest cuối để chủ dự án duyệt production riêng.

Điều kiện đạt: không có lỗi quyền/overbooking/duplicate/lệch paid; tất cả ca
trong ma trận có bằng chứng, index READY, restore thành công, chi phí trong
ngân sách; không coi Emulator 40/40 là thay thế các bước staging này.

## 7. Thứ tự production sau staging và một lần duyệt riêng

1. **Đóng gói ứng viên**: nếu staging cần sửa, dùng commit mới và hash mới, không
   gọi tiếp là nguyên trạng 5084af0. Chốt 6 service, UID mapping, ca tương lai,
   config/runtime/Worker, người trực cutover, RTO/RPO và giờ bảo trì. Đọc lại
   inventory/drift trước apply; giữ tài nguyên ngoài phạm vi.
2. **Chuẩn bị có kiểm soát**: chỉ sau duyệt mới gắn billing/API/IAM cần thiết,
   backup location, monitoring và protection. Không xem duyệt báo cáo hiện tại
   là quyền thực thi. API khả dụng rồi phải kiểm kê Functions trước triển khai.
3. **Đóng writer và sao lưu T0**: dừng client cũ/ép update, đóng các gate mới,
   ngừng tạo payment, drain/reconcile in-flight/IPN. Backup toàn DB và subcollections,
   Rules/index/config/version app/Worker, mapping; Auth backup riêng mã hóa do
   chủ dự án kiểm soát nếu cần provisioning. Snapshot inventory không thay backup.
4. **Index/Functions gate đóng**: chỉ tên/codebase đã duyệt, index READY; kiểm
   tra health/role/read, không seed hay tạo booking làm health check thật.
   Không để deploy toàn project xóa exports/index cũ chưa kiểm kê.
5. **Chuẩn bị dữ liệu và chuyển Rules/client/Worker** trong cùng cửa sổ: control
   ban đầu đóng, catalog create-if-absent bằng precondition; triển khai bộ tương
   thích. Khi đã chặn legacy writer, mở roster/staff có duyệt để link/xếp ca
   bằng backend; đối chiếu audit và coverage, booking/payment vẫn đóng.
6. **Mở booking trả sau có giám sát** sau xác minh config/version/ca/quyền.
   Gate hiện là toàn feature, **không có allowlist canary**: canary là nhóm test
   điều phối trong cửa sổ giới hạn, không hứa kỹ thuật chỉ nhóm ấy mới ghi.
   Nếu yêu cầu canary cưỡng chế theo tài khoản, cần bản sửa riêng trước mở gate.
7. **Payment riêng**: chỉ mở tạo payment sau sandbox/đối soát/Worker tương thích.
   Nếu chưa đạt, gate payment tiếp tục đóng; UI pay-now vẫn có thể hiện nên phải
   duyệt trải nghiệm/tắt nút ở bản phát hành trước khi tuyên bố hỗ trợ trả sau
   duy nhất. Không đổi sang VNPAY live trong đợt Firebase này.
8. Theo dõi lỗi/chi phí/đối soát, mở rộng sau duyệt; bảo toàn lịch 02/11 chờ xử
   lý thủ công. Không merge main/deploy tự động theo commit/push tài liệu.

## 8. Sao lưu, khôi phục và điểm dừng

Backup có checksum, owner, retention, thời điểm và danh sách collection/subcollection;
quyền bucket/khóa mã hóa được duyệt. Backup Firestore không bao gồm Auth/Rules/
secret Worker/ảnh Storage: sao lưu/version hóa riêng khi có quyền. Không đưa
hash mật khẩu/token/private key vào report/Git. Đề xuất mục tiêu RTO 30 phút
cho rollback cấu hình sau diễn tập; RPO cần chủ dự án chốt và đo, chưa cam kết
không mất dữ liệu dựa vào một file export.

| Khi nào dừng | Hành động được đưa ra duyệt trong runbook |
| --- | --- |
| Login/role lỗi, booking treo, overbooking, link sai, index lỗi, chi phí tăng bất thường | Đóng gate ghi mới/payment creation, dừng legacy writer, giữ đọc và IPN đối soát; chụp before/after, không chỉnh tiền/status tùy tiện |
| Code/config có regression | Quay version app/Functions/Worker đã lưu và Rules thực sự online ở T0 chỉ nếu schema/guard tương thích; chưa đối soát thì giữ maintenance, ưu tiên sửa tiến tới |
| Dữ liệu cần phục hồi | Restore snapshot vào DB/project cô lập, so sánh với ghi hợp lệ sau T0, lập patch chọn lọc có updateTime/precondition và duyệt riêng. Không import đè production như Undo |
| Payment đã nhận sau T0 | Giữ paid/audit/order/refundRequired để đối soát; không phục hồi unpaid, không hồi sinh booking hủy, không ngắt IPN chỉ để hạ phiên bản |
| Ca/link/catalog mới cần dừng sử dụng | Giữ lịch sử/UID/link/guard/receipt; inactive/hủy mềm chỉ sau kiểm tra lịch khách và duyệt. Không xóa hay unlink để rollback |

Không bật lại Rules legacy khi writer v2 còn ghi; gate không chặn các writer
ngoài protocol. Managed import có thể ghi đè ID trùng nhưng không xóa document
khác, nên không hoàn tác toàn bộ trạng thái. Ghi nhận và bảo toàn giao dịch hợp
lệ sau T0 là điều kiện trước phục hồi. Không xóa dự án, DB, tài khoản hoặc dữ liệu
hiện có, không tắt billing như một cách rollback khiến mất dịch vụ/IPN.

## 9. Các quyết định cần chủ dự án duyệt tiếp

- Đợt staging riêng: tên/owner/region, thời gian, dự trù 5–20 USD, người nhận cảnh
  báo; quyền/API nào được phép thay đổi và phạm vi secret sandbox.
- Chuẩn bị cục bộ cấu hình staging an toàn, min/max runtime và các test cloud
  thiếu; tối ưu query/polling nếu không đạt ngân sách. Chưa làm trong bản report.
- Giá 6 dịch vụ, tên/giờ 3 chi nhánh, chính sách voucher không hoàn lượt khi hủy,
  mapping Auth→employee và ca tương lai; các danh sách còn trống không được apply.
- Cửa sổ cập nhật ứng dụng cũ, phương án canary/maintenance có thể thực thi,
  backup/PITR/protection và RTO/RPO, cách đối soát/refund và phạm vi trả sau.

**Duyệt bước staging không bao gồm duyệt production.** Sau staging cần trình lại
commit/config/dữ liệu cụ thể, kết quả/chi phí và rollback rehearsal trước bất kỳ
thay đổi thật nào ở `men-hair-booking`.
