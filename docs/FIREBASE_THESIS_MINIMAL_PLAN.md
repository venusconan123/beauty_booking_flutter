# Phương án tối thiểu, tiết kiệm cho khóa luận

Cập nhật 09/11/2026 theo commit **`fab7765f7ab90e321754445ecb43ef76b005b3c3`**,
nhánh `codex/staff-phase-one`. Trạng thái **bản duyệt, chưa thực thi**.
Kiểm thử Web trực tiếp trước commit: [OPTIMIZED_WEB_EMULATOR_VERIFICATION.md](OPTIMIZED_WEB_EMULATOR_VERIFICATION.md).
Đích duy nhất: project hiện có `men-hair-booking`, Firestore Standard `(default)`,
`asia-southeast1`. Không tạo project staging theo yêu cầu mới. Giữ các bản báo
cáo trước để đối chiếu; dự toán pilot 50–80 USD ở đó không phải phí tối thiểu
Firebase hoặc ước tính phù hợp cho ít người dùng của khóa luận.

Lần cập nhật này chỉ đối chiếu phần thay đổi 5084af0→fab7765 và hash các tệp
đã rà soát. Rules, indexes và cấu hình preview không đổi giữa hai commit;
không chạy lại suite hay kiểm kê cloud khi mã runtime không đổi từ lần kiểm
thử cuối. Kế thừa Emulator 43/43, Flutter 22/22, analyze/build sạch và Web hai
tab đã đạt. Inventory/billing/IAM/dữ liệu cloud trong manifest vẫn là quan sát
trước đó, **không được coi là đã kiểm tra lại hôm nay**.

## 1. Phương án đề nghị

- Một project hiện có: Firebase Auth email/password, Firestore và Functions Gen 2.
  Không thêm database, Cloud SQL, App Hosting, VM, Scheduler hoặc project mới.
- Chạy Web local để bảo vệ demo trước; nếu cần URL gửi hội đồng, dùng **Firebase
  Hosting tĩnh** cho Flutter Web sau khi được duyệt. Không cần App Hosting SSR.
- Đặt lịch thanh toán sau là luồng tối thiểu. Giữ paymentCreation gate đóng,
  chưa thêm tài nguyên/merchant VNPAY hoặc Worker mới. Worker hiện có và IPN
  đang tồn tại vẫn phải đối soát trước cutover, không tự tắt/xóa.
- Giữ Auth/15 hồ sơ employees/lịch cũ; link tài khoản và thêm ca tương lai chỉ
  từ danh sách duyệt. Không import tài khoản demo vào Firebase thật.
- Không cần PITR/backup schedule liên tục cho đợt demo ngắn nếu chủ dự án chấp
  thuận; vẫn cần **một bản sao lưu đã kiểm tra trước lần ghi/deploy thật**,
  phiên bản Rules/index/app/config và phương án phục hồi. Không đổi/xóa dữ liệu
  hoặc trạng thái lịch ngày 02/11 để giảm chi phí.

**Phải phân biệt bật billing với phát sinh tiền:** giữ backend kiểm tra trùng
và phân quyền hiện tại thì deploy Functions cần Blaze và billing account.
Blaze không có phí thuê bao tối thiểu cố định cho project; có thể vẫn nằm trong
hạn mức miễn phí, nhưng build/image/log/network và phần vượt hạn mức có thể
tính tiền. Nếu không muốn gắn billing, tiếp tục Emulator; không thể deploy 12
Functions này trên Spark. Không chuyển kiểm tra lịch/trùng giờ chỉ sang client
để né billing. [Functions requirement](https://firebase.google.com/docs/functions/get-started).

## 2. Dịch vụ nào cần billing, mục nào có thể miễn phí?

| Dịch vụ | Đề xuất khóa luận | Billing và khả năng phát sinh phí |
| --- | --- | --- |
| Auth email/password | Dùng tài khoản hiện có, xác minh email | Có hạn mức miễn phí; số người demo rất nhỏ phù hợp. Không dùng Phone Auth/SMS hoặc SAML/OIDC; nếu bật Identity Platform phải theo quota của gói đó |
| Firestore Standard | Giữ DB/vùng hiện có | Có miễn phí cho một DB/project: 50.000 reads/ngày, 20.000 writes/ngày, 1GiB storage; vượt trên Blaze tính phí. Listener, Rules reads, retries và index/storage cũng phải tính |
| Functions Gen 2 | Bắt buộc cho backend hiện tại | **Cần Blaze**, nhưng request/compute có free tier; không phải mỗi callable mất phí cố định. CPU/RAM/network thực tế và quota billing account quyết định hóa đơn |
| Cloud Build/Artifact Registry | Phụ thuộc bắt buộc khi deploy Functions | Có free allowances, vượt thì tính riêng; không miễn phí vô hạn chỉ vì ít người dùng. Giảm số lần deploy, theo dõi dung lượng ảnh build; chưa bật cleanup/xóa image tự động |
| Firebase Hosting tĩnh | Tùy chọn khi cần URL công khai | Hạn mức miễn phí có thể đủ demo; không cần mua domain. Giữ các release cần rollback, không tự xóa release cũ |
| Cloud Storage ảnh kiểu tóc | Tùy chọn cho luồng lịch, giữ ảnh/tài nguyên cũ | Từ 03/02/2026 dùng Storage cần Blaze. Bucket `*.firebasestorage.app` chịu giá GCS; không giả định bucket Singapore được Always Free của các vùng US. Không upload thêm ảnh nếu không cần; không xóa ảnh hiện có |
| Managed export/backup/PITR | Một backup trước apply; chưa bật schedule/PITR liên tục | Cần billing, các mục này không thuộc Firestore free usage; export tính reads và storage, restore/import tính phí. Với dữ liệu nhỏ thường ít nhưng không cam kết 0 |
| VNPAY/Worker | Chưa mở tạo payment trong đợt tối thiểu | Ngoài Firebase; giữ ngoài dự toán core, không nâng gói/tạo Worker mới. Không tuyên bố hỗ trợ VNPAY live |

Nguồn đọc ngày lập: [Firebase pricing](https://firebase.google.com/pricing),
[Firestore billing](https://firebase.google.com/docs/firestore/pricing),
[Hosting quotas](https://firebase.google.com/docs/hosting/usage-quotas-pricing),
[Storage billing requirement](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024),
[export/import](https://firebase.google.com/docs/firestore/manage-data/export-import).
Hạn mức theo ngày không được cộng dồn cả tháng để bù ngày vượt. Free compute
có thể dùng chung theo billing account, không nhân cho 12 Functions.

## 3. Tối ưu mã nguồn đã thực hiện cục bộ

| Trước | Sau |
| --- | --- |
| Danh sách thợ tải lại mỗi 10s; stream còn tạo lại trong build khi chọn thợ | Một stream ổn định/màn hình, tải một lần; tải lại khi bấm Làm mới hoặc quay về từ chọn giờ |
| Trang chi tiết salon cũng tạo lại stream thợ khi dựng/chuyển tab | Giữ Future kết quả trong vòng đời trang; không gọi lại khi chuyển tab/hotline cập nhật; có Làm mới/Thử lại, không treo spinner khi tải lỗi |
| Giờ trống gọi mỗi 5s dù không thao tác | Tải lúc mở, đổi ngày, Làm mới hoặc quay về từ xác nhận; không timer polling |
| Kết quả request cũ có thể ghi lại dữ liệu sau refresh cùng ngày | Generation guard bỏ qua phản hồi cũ; refresh xóa giờ đã chọn, giờ không khả dụng không bấm được |
| getAvailability/createBooking đọc mọi ca của salon rồi lọc ngày trong RAM | Query salonId + dateKey của ngày được yêu cầu |
| listBookableStaff đọc mọi ca của salon | Query salonId + dateKey trong 7 ngày tới; dùng index salonId/dateKey sẵn trong file |
| loadDay đọc mọi ca của employee rồi lọc ngày | Query employeeId + dateKey, vẫn kiểm tra mọi chi nhánh, không thêm salon filter làm mất xung đột |
| A/B đọc lại profile/lịch hẹn cùng người ở cả hai ngày | Dùng chung lần đọc trong một transaction attempt; vẫn đọc đủ bốn day guards, không cache qua request/retry |
| Loyalty đọc mọi lịch của user rồi lọc completed | Query userId + status=completed ngay trên Firestore; giữ thưởng atomic/idempotent |
| Runtime không pin giới hạn | Tất cả callable: minInstances=0, maxInstances=2, 256MiB, cpu=gcf_gen1, concurrency=1 |

Không thay Rules, schema hoặc ghi Firebase thật cho các tối ưu này. Các query
equality có thể dùng index merging; query range salonId/dateKey có composite
đã khai báo. Chưa kiểm tra index cloud thực tế, không tự tạo/xóa index. Fractional
CPU giảm tài nguyên ở tải nhỏ nhưng có thể chậm hơn CPU=1, cần thử cloud sau
duyệt. MaxInstances là **mỗi Function**, không phải tổng hai instances và không
phải trần hóa đơn. [Runtime options](https://firebase.google.com/docs/functions/manage-functions).

**Độ đúng vẫn do backend quyết định:** dữ liệu giờ trống có thể cũ trong lúc
khách đứng yên. Khi lưu, transaction vẫn kiểm tra lại ca/chi nhánh/thời lượng/
booking và guards. Nếu vừa có người khác đặt, backend từ chối, khách làm mới và
chọn lại. Không cache availability ở server, không bỏ kiểm tra để tiết kiệm.

**Phần chưa bỏ quét:** loadDay vẫn đọc lịch hẹn theo barberId và lọc trạng thái/
ngày ở RAM. Lịch legacy có thể thiếu dateKey/endAt/status; tự thêm filter mới
có thể bỏ sót lịch bận hoặc dữ liệu lỗi. Giữ kiểm tra bảo thủ, chỉ tái sử dụng
đọc trong cùng attempt. Với vài chục/vài trăm lịch và không polling, đây là đánh
đổi hợp lý. Nếu tăng quy mô phải duyệt chuẩn hóa legacy/định nghĩa interval rồi
mới giới hạn query; không tự migrate hoặc xóa lịch sử trong lượt này. Dashboard/
lịch sử admin còn đọc toàn bộ collection, cũng chưa chuyển phân trang đợt này.

## 4. Dự trù sát quy mô demo

Giả định **20 lượt thử/ngày**, mỗi lượt mở hai màn hình, đổi/thử một vài ngày,
tổng khoảng **5 read callables/lượt**: khoảng 100 request/ngày, 3.000/tháng.
Mutation/refresh chủ động tính thêm. Giả sử trung bình 50 document reads/call
thì khoảng 5.000 reads/ngày cho nhóm này, thấp hơn quota 50.000; vẫn cộng thêm
listener/Rules/admin/history/retry và các ứng dụng khác cùng project.

Để so sánh: nếu đứng 10 phút trên **mỗi** màn hình, timer cũ tạo 60 calls danh
sách + 120 calls giờ trống = 180 calls/lượt, khoảng 108.000 calls/tháng ở 20
lượt/ngày, chưa tính stream restart trong build hoặc route bị che vẫn mounted. Nay khi đứng yên không phát
sinh thêm callable. Đây là mô hình tính request từ source, không phải bill đo
cloud hoặc cam kết số reads thực tế.

**Mục tiêu dự trù core: khoảng 0–5 USD/tháng**, không có gói cố định phải mua
50–80 USD/tháng. Có thể rất gần 0 nếu nằm trong free tier; khoản nhỏ build/image/
network/backup vẫn có thể xuất hiện. Chưa VAT/tỷ giá, SMS, bank fee, tải ảnh lớn
hoặc traffic bất thường. Dự trù này không phải cap hoặc bảo đảm hóa đơn.

Đề xuất budget alerts **1/3/5 USD** (chọn budget 5 USD, ngưỡng 20/60/100%) và
theo dõi Usage khi demo. Budget alerts không tự ngừng tất cả dịch vụ; spend-cap
nếu Console có là cơ chế riêng, phạm vi hạn chế, chưa bật. Không dùng tắt billing
làm công tắc ngắt khẩn cấp khi còn thanh toán/IPN.
[Billing budgets](https://firebase.google.com/docs/projects/billing/avoid-surprise-bills).

## 5. Kết quả kiểm thử và giới hạn

- Flutter: 22/22; hai widget tests mới chứng minh chọn thợ/rebuild/chờ 1 phút
  không tăng request, Làm mới phục hồi lỗi và phản hồi giờ trống cũ không ghi đè
  kết quả mới. Analyze sạch.
- Emulator: **43/43 đạt** (thêm 3 ca trên suite 40 ca). Đo documents trả về từ query thật: 120
  ca ngoài khoảng không được tải về khi list/availability/booking; A/B đọc lịch
  cùng người một lần/attempt và giữ đủ day guards; lịch active thiếu timestamp
  vẫn bị chặn. Vòng đầu một fixture cố ý lỗi ảnh hưởng test sau, đã cô lập rồi
  chạy lại toàn suite, 43 đạt/0 lỗi trong 66,9s. Logs: `.dart_tool/low-cost-emulators-verified.log`.
- Web release dùng Emulator build cục bộ **đạt**; đã chạy lại Web server mới
  (51,8s) và kiểm thử trực tiếp hai tab như báo cáo liên kết ở đầu. Không dùng widget/build để tuyên bố
  đã thử native Chrome/Android/cloud. Chưa đo bill/quota/
  fractional CPU/cold start trên cloud, chưa thử index cloud READY.
- Logs/build/dữ liệu Emulator trong .dart_tool/build, không đưa vào Git; giữ
  thay đổi báo cáo đang có và helper kiểm tra quyền có trước. Gói commit chỉ gồm
  mã nguồn, cấu hình, kiểm thử và tài liệu, không phải triển khai cloud.

## 6. Các bước bạn làm trên Console

### A. Có thể làm ngay: chỉ xem, không Save/Enable/Publish

| Bước | Đường đi trên Console | Ghi nhận để duyệt |
| --- | --- | --- |
| A1 | Firebase Console → chọn `men-hair-booking` → bánh răng Project settings → General | Xác nhận **Project ID**, Web/Android app hiện có và vùng DB; không tạo app/project mới, không gửi secret |
| A2 | Bánh răng → Usage and billing → Details & settings; xem tab Usage nếu có | Plan đang dùng, có billing account hay chưa; dừng nếu thấy Upgrade, không bấm xác nhận nâng gói |
| A3 | Authentication → Sign-in method; Users | Xem Email/Password đang bật hay không; đối chiếu UID/email/email verified của tài khoản hiện có. Chốt bảng UID→employeeId→chi nhánh; không tạo tài khoản hoặc đổi mật khẩu để thử |
| A4 | Authentication → **Settings → Authorized domains** | Ghi domain Web định dùng có sẵn hay chưa. Đây không phải mục Sign-in method. Chưa Add domain; nếu chạy local với Firebase thật thì hostname local cũng cần được xem xét riêng |
| A5 | Firestore Database → chọn `(default)` → Data | Xem services, employees, staff_accounts/employee_accounts/work_shifts/app_settings có thay đổi so baseline hay không. Chốt bảng dữ liệu ở mục 8, không nhập thử document; lịch 02/11 giữ nguyên |
| A6 | Firestore Database → Rules và Indexes → Composite | Lưu bản Rules đang published, ghi các index hiện có/trạng thái. Không bấm Publish hoặc Add index trong lượt chuẩn bị. Cần giữ index ngoài phạm vi nếu đã có người thêm |
| A7 | Functions trong menu Firebase (Build/Run tùy giao diện) | Nếu thấy Get started/Upgrade/API disabled thì ghi nhận rồi dừng; không suy rằng project không có Functions. Nếu có danh sách, ghi tên/region/codebase, không xóa hoặc redeploy |
| A8 | Hosting/Storage → Usage nếu đang có dịch vụ | Chọn Web local hay cần URL Hosting, ghi nhận dung lượng/traffic/ảnh hiện có. Không chạy wizard tạo site/bucket; không dọn dữ liệu/release |

Tên nhóm menu có thể được Firebase đổi; tên trang đích ở bảng là nơi cần mở.
Nguồn: [Auth settings](https://firebase.google.com/docs/auth/faq-and-troubleshooting),
[authorized domains](https://firebase.google.com/docs/auth/web/email-link-auth),
[index management](https://firebase.google.com/docs/firestore/query-data/indexing).

### B. Chỉ sau khi bạn duyệt riêng billing/API/backup và gói ở mục 7–8

1. **Bật billing nếu chọn đưa Functions lên cloud:** Firebase → bánh răng →
   Usage and billing → Details & settings → Modify plan/Upgrade → chọn Blaze,
   owner chọn billing account và xác nhận. Nếu thiếu quyền billing account,
   nhờ billing admin; không tự cấp Owner hoặc quyền rộng cho agent. Không làm
   bước này trong lượt cập nhật báo cáo hiện tại.
2. **Cảnh báo chi phí:** từ billing account mở Google Cloud Billing → Budgets
   & alerts → Create budget → chọn phạm vi project `men-hair-booking` → monthly
   budget 5 USD **nếu account tính USD** (nếu tiền tệ khác, bạn chốt mức tương
   ứng) → alerts 20%, 60%, 100% = 1/3/5 USD → kiểm tra email người nhận rồi lưu.
   Chọn alerts-only; không tự bật spend cap. Budget không phải trần hóa đơn.
   [Billing plan](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans),
   [budget guidance](https://firebase.google.com/docs/projects/billing/avoid-surprise-bills).
3. **API:** Google Cloud Console → chọn đúng cùng project → APIs & Services →
   Enabled APIs & services; vào Library chỉ khi cần bật phần thiếu:
   `cloudfunctions.googleapis.com`, `run.googleapis.com`, `cloudbuild.googleapis.com`,
   `artifactregistry.googleapis.com`. Kiểm tra Firestore/Auth/Rules/Logging và
   Storage API cho backup theo inventory; không bật App Hosting/SQL/Vertex AI/
   Scheduler. Đợi API có hiệu lực, kiểm kê Functions đang có và runtime/build
   identity trước deploy; mọi quyền thiếu phải báo bạn, không tự nâng quyền.
4. **Backup T0:** chốt bucket/đường dẫn, người giữ bản sao, retention và chi phí.
   Dừng/drain writer cũ và request đang chạy trong cửa sổ bảo trì trước chụp T0.
   Google Cloud Console → Firestore → Import/Export → Export toàn bộ collections
   và subcollections vào nơi đã duyệt; nếu chưa có bucket phù hợp thì dừng để
   duyệt tài nguyên đó, không dùng wizard tạo ngẫu nhiên. Kiểm tra operation
   hoàn tất và bản sao khôi phục được; lưu Rules/index/config/app/Worker version
   riêng. Firestore backup không thay Auth/Storage/secret backup. Không bật
   scheduled backups/PITR trong gói tối thiểu nếu chưa có duyệt riêng.
5. **Cửa sổ triển khai:** dùng gói đã chốt ở mục 7, không dán/publish Rules trước
   khi có client/Functions tương thích và backup. Sau Functions/index READY và
   chặn writer cũ, apply control/các dữ liệu được duyệt; mở staff/roster để chuẩn
   bị link/ca, booking/payment còn đóng. Hai chiều link và ca phải tạo bằng UI
   admin/backend, không gõ tay vào collection nội bộ.
6. **Mở demo trả sau:** chỉ mở bookingWritesEnabled sau kiểm tra ca/quyền/config,
   với nhóm test/dữ liệu được duyệt. Giữ paymentCreationEnabled=false. Chọn
   “Thanh toán sau”; fab7765 chưa ẩn nút pay-now nên không hứa giao diện đã tắt
   hoàn toàn lựa chọn ấy. Nếu cần ẩn phải duyệt bản sửa riêng. Xem Functions
   logs và Firestore Usage; kiểm tra CORS/cold start/quyền/đặt trùng trên cloud
   có giám sát, không tự tạo booking thật làm health check.
7. **Hosting tùy chọn:** nếu cần URL công khai, duyệt bổ sung cấu hình Hosting
   và build production không có FIREBASE_EMULATORS=true. Gói preview hiện chưa
   có Hosting, không bấm Get started để thay cho cấu hình đã rà soát. Khi có URL,
   xem A4, thêm đúng bare hostname nếu cần rồi Save; không xóa domain hiện có.

## 7. Gói Functions / Rules / indexes cần duyệt

Nguồn cố định **fab7765**, `firebase.production.preview.json` là cấu hình đề xuất;
`firebase.json` hiện không chứa Functions và có Storage Rules nên **không dùng
deploy toàn project**. Workspace không có `.firebaserc`: khi thực thi sau duyệt
phải chỉ định rõ project `men-hair-booking` và config preview, không dựa alias
mặc định. Báo cáo này không chạy lệnh deploy hoặc tạo tài nguyên.

| Gói | Tệp/giá trị được đưa ra duyệt | Phạm vi và điều kiện |
| --- | --- | --- |
| Functions | `functions/package.json`, `package-lock.json`, 5 module `src/index.js`, `staff.js`, `scheduling.js`, `write_control.js`, `loyalty.js` | Gen 2, Node 22, codebase staff, asia-southeast1; minInstances=0/maxInstances=2 **mỗi callable**, 256MiB, cpu=gcf_gen1, concurrency=1. Không có trigger/schedule/seed/migration khi load |
| 12 exports | linkStaffAccount, setStaffAccountActive; saveRoster, saveShifts, cancelShift, swapShifts; createBooking, updateBookingServices, changeBookingStatus; getAvailability, listBookableStaff; releaseStaleSlots | Kiểm kê tên online trước apply, không xóa export/codebase cũ ngoài phạm vi; gate đóng mặc định, releaseStaleSlots không tự chạy |
| Rules | Toàn bộ `firestore.rules`, SHA trong manifest; diff cloud-baseline ở `production-preview/live-to-candidate.rules.patch` | Không đổi so 5084af0. Backend-only bookings/slots/shifts/guards/receipts/link/audit writes; staff active xem đúng lịch được giao/ca chi nhánh; customer không tự sửa quota/redemption. Giữ quyền admin hiện có; reports/support còn giới hạn schema cần chấp thuận phạm vi. Không bật legacy bypass |
| Composite index | `firestore.indexes.json`: work_shifts, queryScope COLLECTION, salonId ASC + dateKey ASC | Một index đã khai báo, không đổi so 5084af0. Chỉ thêm nếu chưa có bản tương đương, không xóa index online khác. Đợi READY/Enabled. Equality employeeId/dateKey và userId/status dùng index merging; nếu cloud báo thiếu index thì đưa index cụ thể ra duyệt, không tự thêm đoán |
| Flutter client | Mã cùng fab7765: FirebaseOptions project thật, transport HTTPS, giao diện staff/roster/booking và bỏ polling | Phải phát hành cùng đợt Rules/Functions; không phục vụ build Emulator cho Firebase thật. Hosting/Android distribution là lựa chọn phát hành riêng |
| Loại trừ | Hosting/Storage Rules/Worker, node_modules, test/tools/logs, .env/key/build/Emulator export | Không triển khai bằng config preview, không tạo Auth user hoặc import dữ liệu demo |

**Điều kiện Worker dù gói tối thiểu trả sau:** Worker online chưa được kiểm kê
lại. Gate paymentCreation chỉ có hiệu lực ở Worker có hỗ trợ cờ; nó không dừng
Worker cũ hoặc IPN đang bay. Trước mở guarded booking phải xác nhận không còn
payment writer cũ tranh chấp, drain/đối soát giao dịch, hoặc duyệt Worker tương
thích thành gói riêng. Nếu chưa xác nhận được thì giữ ghi mới đóng; không tự
deploy Worker, ngắt IPN hoặc bỏ qua ràng buộc vì số người dùng ít.

So với 5084af0, chỉ ba module backend index/scheduling/loyalty đổi (runtime/query/
cache trong transaction), các màn hình tải dữ liệu và test đổi. Rules/index/
package dependencies/preview config không đổi. Các kết quả 43/43, 22/22 và Web
77s/71s không polling được kế thừa; chưa có bằng chứng index/runtime cloud.

## 8. Gói dữ liệu cần duyệt trước khi ghi

Chi tiết máy đọc: [data-change-preview.json](production-preview/data-change-preview.json),
`approved=false`, `executed=false`. **Chưa có migration executable**.

| Document service đề nghị tạo nếu còn thiếu | Giá VND | Phút |
| --- | ---: | ---: |
| services/service_hair_cut | 80.000 | 30 |
| services/service_hair_wash | 30.000 | 20 |
| services/service_styling | 50.000 | 30 |
| services/service_perm | 250.000 | 120 |
| services/service_dye | 300.000 | 150 |
| services/service_skin_care | 100.000 | 45 |

Giá/thời lượng đều chờ bạn duyệt; các trường name/isActive/order/timestamps
trong preview phải được áp dụng đúng kiểu dữ liệu. Giữ `service_combo_10` và
mọi document hiện có; create-if-absent có re-read/precondition, gặp drift thì
dừng, không ghi đè. Không nhập từng service thủ công lúc chưa duyệt gói.

Control đề nghị tạo `app_settings/scheduling_v2` (nếu đã có phải so before-image):

```json
{
  "protocolVersion": 2,
  "bookingWritesEnabled": false,
  "rosterWritesEnabled": false,
  "staffWritesEnabled": false,
  "paymentCreationEnabled": false
}
```

Đổi cờ sau đó là thao tác ghi thật riêng cần duyệt; cờ không khóa profile/chat/
catalog ngoài protocol và không thay cửa sổ bảo trì. Không nhập control ngay.

- **Staff:** approvedMappings hiện trống. Bạn cần điền UID Auth đã tồn tại,
  verified/enabled → employeeId hiện có → salon chính; không chọn admin làm
  staff hoặc suy UID theo tên. Backend tạo staff_accounts/employee_accounts
  và audit đồng thời, không tạo Auth/đổi mật khẩu/UID/xóa tài khoản.
- **Ca:** approvedAssignments hiện trống. Cần chi nhánh, employee, ngày tương
  lai, mã ca/giờ hoặc OFF và expected revision. Dùng admin preview + saveRoster;
  đổi A/B kiểm tra bốn tổ hợp và trùng xuyên chi nhánh, không tự lấp cả tháng.
- **Sinh khi vận hành, không seed trước:** booking mới/slots/day guards/
  schedule_operations/audit và notifications; voucher quota/redemption trong
  transaction. Checkout có thể sửa users.phone/updatedAt dù gate booking đóng.
  Hủy không hoàn lại lượt voucher trong bản này; cần duyệt chính sách ấy.
- **Giữ nguyên:** 48 booking baseline, snapshot giá/ID, Auth, employees/admin;
  không thêm schemaVersion/workShiftId hồi tố, không tự tính lại tiền/thưởng.
  Baseline count chưa đọc lại. Lịch 02/11/2026 09:30–10:30 salon_01 giữ nguyên
  chờ bạn đối chiếu. Không xóa dữ liệu, nhập Emulator hoặc cấp role bằng tay.
- **Thông tin còn cần chốt:** tên/giờ ba chi nhánh (salon_03 còn “mô phỏng”),
  UID mapping, ca, bucket backup, cửa sổ ép cập nhật client cũ, danh tính test
  thật được phép và có/không cần Hosting. Các mục trống chưa đủ để apply.

## 9. Điểm dừng và khôi phục tối thiểu

Trước T0 lưu Rules thực sự online, index/config/phiên bản app/Functions/Worker
và backup toàn DB dùng được. Lỗi role, overbooking, index chưa READY, login/
mutation thất bại hoặc chi phí bất thường: đóng ghi mới/payment creation,
giữ đọc và IPN đối soát, không bật lại legacy writer khi writer v2 còn chạy.
Rollback version chỉ khi tương thích schema/guards; nếu không, giữ bảo trì
để sửa tiến tới. Restore vào nơi cô lập trước rồi lập patch chọn lọc có
precondition cho bạn duyệt; không import đè production như Undo, không mất
giao dịch sau T0, không hạ paid→unpaid hoặc phục hồi booking đã hủy. Không xóa
project/database/tài khoản/guard/receipt/ca để rollback, không tắt billing.

**Cần duyệt riêng trước thực thi:** (1) Blaze/budget/API/quyền và backup một lần;
(2) source fab7765 + 12 Functions + toàn bộ Rules + một index + client tương
thích; (3) control/6 service/UID mapping/ca/policy voucher cụ thể; (4) lịch
cutover, xử lý Worker/in-flight và cloud smoke test có giám sát. Duyệt báo cáo
không tự có nghĩa cho phép bật billing, publish Rules, ghi dữ liệu hoặc deploy.
