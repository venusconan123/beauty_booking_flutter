# Phương án tối thiểu, tiết kiệm cho khóa luận

Cập nhật 09/11/2026, dựa trên 5084af0 và gói tối ưu trên nhánh `codex/staff-phase-one`.
Kiểm thử Web trực tiếp trước commit: [OPTIMIZED_WEB_EMULATOR_VERIFICATION.md](OPTIMIZED_WEB_EMULATOR_VERIFICATION.md).
Đích duy nhất: project hiện có `men-hair-booking`, Firestore Standard `(default)`,
`asia-southeast1`. Không tạo project staging theo yêu cầu mới. Giữ các bản báo
cáo trước để đối chiếu; dự toán pilot 50–80 USD ở đó không phải phí tối thiểu
Firebase hoặc ước tính phù hợp cho ít người dùng của khóa luận.

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

## 6. Bạn cần làm gì tiếp trên Console?

**Bây giờ chỉ xem và chốt phương án, chưa bật gì:**

1. Mở [Firebase Console](https://console.firebase.google.com/), chọn đúng
   `men-hair-booking`. Xem Usage and billing: Spark/Blaze hiện tại và Usage của
   Firestore/Hosting/Storage, chụp số liệu để đối chiếu; không tạo project/DB mới.
2. Authentication → Sign-in method: xem Email/Password và authorized domains;
   Authentication → Users: đối chiếu UID/email verified hiện có với danh sách
   nhân viên định liên kết. Không gửi password/token/key, không tự tạo demo thật.
3. Firestore → Data/Indexes: xem catalog, ca/link đã có và index salonId/dateKey;
   không sửa bằng tay. Chốt 6 giá/thời lượng dịch vụ, UID mapping và ca tương lai.
   Lịch 02/11 giữ nguyên chờ bạn đối chiếu.
4. Chọn demo Web local hoặc cần Hosting URL; chọn thanh toán sau. Chốt dự trù
   0–5 USD/tháng và đồng ý hay không việc gắn billing để deploy Functions.

**Sau khi bạn duyệt một đợt triển khai riêng, mới làm các bước sau:**

5. Usage and billing → Details & settings/Modify plan → Blaze: owner tự gắn
   billing account/phương thức thanh toán nếu chọn deploy. Không nâng quyền cho
   agent; nếu account thiếu quyền gắn billing thì nhờ billing admin. Đặt budget
   5 USD và alerts 1/3/5 USD trong Google Cloud Billing, người nhận là bạn.
6. Trong Google Cloud Console **cùng project**, APIs & Services: kiểm tra và bật
   phần còn thiếu của Cloud Functions, Cloud Run, Cloud Build, Artifact Registry.
   Firestore/Auth/Rules/Logging/Storage APIs kiểm tra theo nhu cầu thực tế; không
   bật App Hosting, SQL, Vertex AI, Scheduler hoặc dịch vụ ngoài phạm vi. Đọc lại
   Functions inventory và service-account permissions; thiếu quyền phải báo bạn.
7. Duyệt backup một lần và tạo bản sao đã kiểm tra trước apply; snapshot Rules/
   indexes/config/version hiện hành. Giữ các gate đóng. Chưa gõ control/link/
   ca vào Data cho tới khi danh sách thay đổi và runbook được duyệt.
8. Trình lại bản code/hash/tests, danh sách dữ liệu và cutover cho bạn duyệt.
   Mới deploy Functions/index/Rules/client tương thích trong cửa sổ demo bảo trì;
   không để client cũ ghi bypass backend, không mở gate booking trước có ca.
   Nếu cần Hosting, phát hành riêng build tĩnh sau duyệt, thêm authorized domain
   đúng URL. Không dùng `.dart_tool` hoặc bản Emulator làm build Firebase thật.
9. Thử có giám sát bằng danh tính/dữ liệu đã duyệt trên project hiện có, không
   chạm lịch sử; theo dõi Usage, role, CORS, trùng ca/booking và lỗi gate. Vì không
   có staging riêng, cloud smoke test vẫn là một thao tác thật cần duyệt, không
   tự thử ghi chỉ để xác nhận kết nối. Nếu lỗi, đóng ghi và rollback theo runbook,
   không xóa dữ liệu/import đè hoặc merge main tự động.

Phương án này giảm hạ tầng và kiểm thử cloud riêng theo quy mô khóa luận, không
bỏ backend validation, sao lưu trước apply hoặc quyền duyệt dữ liệu thật.
