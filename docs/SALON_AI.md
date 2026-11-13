# Trợ lý AI salon — Firebase thật, Cloudflare Free

## Sử dụng

Trang chủ → **Trợ lý AI**, chọn chi nhánh/ngày hoặc nêu trực tiếp trong câu hỏi.
Ví dụ:

- “Uốn tóc bao nhiêu tiền, làm bao lâu?”
- “Ngày 19/12/2026 tôi muốn uốn tóc ở Nguyễn Văn Linh thì có thợ nào phù hợp?”
- “Buổi chiều thì sao?”
- “Nhân viên Lê Quốc làm ca nào ngày 19/12/2026 ở Nguyễn Văn Linh?”

Ngày trong ví dụ chỉ dùng khi còn ở tương lai. Bot hiểu “hôm nay”, “mai”,
“mốt”, ngày cụ thể và khung giờ theo Việt Nam. Chỉ tra từ hôm nay đến 90 ngày tới.
Nếu thiếu chi nhánh hoặc dịch vụ, bot hỏi tiếp. Hội thoại chỉ lưu trong bộ nhớ
màn hình, không tạo bản sao dữ liệu khách trên dịch vụ AI.

## Dữ liệu và cách đề xuất

- Worker xác minh Firebase ID token; không tin UID/quyền gửi trong nội dung chat.
- Mô hình `@cf/meta/llama-3.3-70b-instruct-fp8-fast` phân tích câu hỏi thành các
  trường đã giới hạn: dịch vụ, chi nhánh, ngày, giờ, tên thợ và loại câu hỏi.
  AI không nhận service-account key, hồ sơ khách, lịch hẹn hay số điện thoại.
- Backend lấy danh mục `services`, ca `work_shifts`, hồ sơ công khai `employees`
  và đánh giá đã xác minh từ Firebase `men-hair-booking`, database `(default)`.
- Tất cả giờ trống lấy từ chính `getAvailability`, kiểm tra cả thời lượng dịch
  vụ và các lịch hẹn ở mọi chi nhánh của nhân viên. Không dùng AI đoán giờ rảnh.
- Ưu tiên nhân viên còn giờ, chuyên môn khớp dịch vụ, kinh nghiệm, đánh giá thật.
  Nếu hồ sơ chưa ghi chuyên môn phù hợp, app hiển thị rõ; không tự gán tay nghề.
- Giá, thời lượng, tên và giờ được backend tra cứu trước. Một lượt AI bổ sung
  diễn đạt câu trả lời theo dữ kiện đã có; không được bổ sung dữ kiện mới.
  Phản hồi sai định dạng, chứa số liệu không có trong kết quả, xác nhận đặt
  lịch hoặc khẳng định giờ trống khi chưa tra cứu sẽ dùng lời giải thích dự
  phòng từ backend. Các thẻ thông tin luôn dùng trực tiếp giá trị đã tra cứu.
- Tách riêng tư vấn **chuyên môn** và tra **giờ trống**. Hỏi “thợ nào phù hợp
  với uốn tóc” không tự áp điều kiện ngày hôm nay hoặc loại thợ chưa phân ca.
  Hồ sơ thiếu chuyên môn được giải thích đúng là thiếu dữ liệu. Khi tra lịch,
  chưa phân ca được phân biệt với chưa có giờ phù hợp.
- Có thể tìm chuyên môn ở cả ba chi nhánh, ghi rõ chi nhánh của từng thợ.
  Gợi ý câu hỏi tiếp theo chỉ hỗ trợ tra cứu, không tự đặt lịch.
- Chỉ tư vấn, không tự tạo lịch, sửa ca, hoàn thành lịch hay thu tiền. Nút đặt
  lịch chuyển sang màn hình chọn giờ hiện có với thợ/dịch vụ/ngày đã chọn.
  Backend kiểm tra lại tại thời điểm khách xác nhận đặt lịch.

Endpoint: `POST /api/scheduling/askSalonAssistant`, qua `SchedulingService`.
Chức năng AI chạy ở Worker online; không chuyển sang Firebase thật khi client
đang được cấu hình dùng Emulator. Emulator Functions chưa tích hợp mô hình AI.

## Giữ miễn phí

Đã quan sát Cloudflare Dashboard ngày 13/11/2026: Workers plans hiển thị
**Free · $0 · Current plan**. Không thay đổi gói/billing, không bật Firebase Blaze.

Wrangler chỉ thêm `AI` binding và giới hạn 10 câu hỏi/60 giây/tài khoản tại mỗi
Cloudflare location. Giới hạn tần suất không phải ngân sách toàn tài khoản.
Workers AI Free có 10.000 Neurons/ngày, dùng chung với các ứng dụng AI khác
trên tài khoản, reset 00:00 UTC. Khi hạn mức hết, yêu cầu thất bại; app báo thử
lại sau và vẫn cho đặt lịch thông thường. Không tự chuyển mô hình trả phí hoặc
tự nâng cấp gói. Nếu chủ tài khoản nâng Workers lên Paid trong tương lai, cần
xem lại cơ chế ngân sách trước khi tiếp tục sử dụng chatbot.

Nguồn: https://developers.cloudflare.com/workers-ai/platform/pricing/

## Kiểm tra và triển khai

```powershell
flutter analyze --no-pub
flutter test --no-pub test/salon_assistant_test.dart test/booking_reads_test.dart
node --test functions/test/salon_advisor.test.cjs cloudflare_worker/test/firestore-rest.test.js cloudflare_worker/test/scheduling-security.test.js
```

Kiểm thử live bên dưới dùng Firebase/AI thật và tiêu thụ một phần hạn mức AI.
Chúng tạo tài khoản Auth thử không có quyền admin/staff, xóa sau khi kiểm tra,
không ghi lịch hẹn, ca làm, đánh giá hoặc thanh toán:

```powershell
node tools/check-salon-assistant-online.cjs
flutter test --no-pub --dart-define=RUN_LIVE_AI_TEST=true test/salon_assistant_live_test.dart
```

Kiểm thử live Flutter mặc định được bỏ qua trong bộ test thông thường.

```powershell
cd cloudflare_worker
node node_modules/wrangler/bin/wrangler.js deploy --dry-run
node node_modules/wrangler/bin/wrangler.js deploy
```

Đã triển khai bản hội thoại tự nhiên ngày 13/11/2026:
`ddaede67-9843-4dba-abe5-ab4c65237f0e`, Worker
`https://men-hair-booking-vnpay.venusconan23.workers.dev`.

Kiểm tra API live: giá uốn **250.000đ / 120 phút**, chi nhánh/ngày đúng; giờ đề
xuất khớp `getAvailability`; hỏi tiếp “buổi chiều” giữ ngữ cảnh; ca Lê Quốc
19/12/2026 trả **14:00–22:00** đúng dữ liệu lúc kiểm tra. Tài khoản thử đã xóa.

Kiểm thử màn hình Flutter với HTTP/AI/Firebase thật đã đạt: nhập câu hỏi,
nhận phản hồi HTTP 200 khoảng 2,9 giây và hiển thị giá/thời lượng cùng giờ
tra cứu. Đây là kiểm thử màn hình tự động, chưa phải thao tác thủ công trên
điện thoại Android. Bản web `build/web-spark` đã build thành công.

Kiểm tra cuối: 72 bài Flutter toàn bộ đã đạt (bài live mặc định bỏ qua),
1 bài bổ sung kiểm tra ngày/thợ từ chatbot và 2 bài booking-read liên quan
đã đạt; 20 bài backend/REST/security đã đạt. Những bài live được chạy riêng
để tránh tự tiêu thụ hạn mức AI mỗi lần chạy bộ test thông thường.
Tài khoản `ai-ui-…@example.test` còn sót từ lần kiểm thử lỗi đã được xóa
bằng công cụ chỉ nhắm đúng namespace của bài test; không xóa tài khoản thật.

Bản cải thiện hội thoại: 16 bài tư vấn backend đã đạt; 9 bài giao diện/booking
đã đạt ở màn hình hẹp và rộng; kiểm thử màn hình với AI/Firebase thật HTTP 200
khoảng 6,7 giây đã đạt; analyzer sạch và web build thành công. Thời gian trả
lời phụ thuộc hai lượt mô hình: hiểu ý định, rồi diễn đạt từ dữ kiện đã tra.
Lượt diễn đạt lỗi/hết hạn mức vẫn hiển thị kết quả đã kiểm chứng, không tự
chuyển dịch vụ AI trả phí.

Câu hỏi thực tế “tôi muốn tra cứu khi tôi uốn tóc thì có thợ nào phù hợp” đã
được xác nhận phân loại `expertise`, không áp điều kiện lịch hôm nay. Hồ sơ
Firebase tại Nguyễn Văn Linh trả Võ Thành và Trần Hoàng có ghi chuyên môn
uốn tóc. Tìm cả ba chi nhánh cũng trả người có chuyên môn kèm đúng chi nhánh.
Câu có ngày/giờ cụ thể vẫn dùng kiểm tra lịch; backend có quy tắc bổ sung
cho trường hợp mô hình chọn nhầm loại yêu cầu. Lời văn tra giờ chỉ nhận các
giờ bắt đầu còn trống, không dùng đầu/cuối ca làm làm giờ có thể đặt.

Sửa lỗi xác nhận ngắn: app gửi tối đa sáu lượt gồm cả khách và trợ lý;
backend chỉ nhận vai trò user/assistant và giới hạn độ dài từng lượt. Phản
hồi chứa `context.pendingAction` mô tả đúng việc vừa được đề nghị. “Có/ok/
được” chỉ xác nhận việc đó, “không” hủy đề nghị, không đủ ngữ cảnh thì hỏi
lại. Không dùng mô hình để tự chọn dịch vụ mới từ một câu xác nhận ngắn.
Câu hỏi tiếp theo được backend ghép vào sau phần diễn đạt để tránh lời hỏi
của AI lệch với hành động đang chờ.

Tư vấn kiểu tóc nam có loại yêu cầu riêng, lấy mẫu đang bật từ `hairstyles`.
Luồng “Tôi mặt tròn thì hợp với mẫu tóc nào?” → “có” đã đạt online: đề xuất
Modern Quiff/Modern Side Part, rồi tìm thợ cho `service_hair_cut` (Nguyễn Minh,
Phạm Tuấn tại thời điểm kiểm tra), không tự chọn uốn/nhuộm hay báo giá các
dịch vụ chưa được yêu cầu. Bộ kiểm thử backend/REST/security 30 bài đạt;
giao diện sáu bài đạt. Các kiểu tóc là gợi ý tham khảo từ danh mục, stylist
cần xem tóc thực tế để điều chỉnh; không nhận diện khuôn mặt từ ảnh.

App chạy từ source cần Hot Restart để hiện nút mới. APK hoặc web đã build trước
bản sửa cần build lại. Việc deploy Worker không tự cập nhật app đã cài.
