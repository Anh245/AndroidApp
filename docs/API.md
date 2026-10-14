# REST API v1

Base URL local: `http://localhost:3000/api`. JSON UTF-8. API nghiệp vụ dùng `Authorization: Bearer <accessToken>`. Refresh/logout chỉ nhận cookie `refreshToken`, không nhận token từ JSON. Mọi POST `/auth/*` gửi `X-Requested-With: expense-manager`; trình duyệt bật `credentials: include` và origin phải thuộc `CORS_ORIGINS`.

| Method | Endpoint | Mục đích |
|---|---|---|
| GET | `/health` (ngoài `/api`) | Kiểm tra API và DB |
| POST | `/auth/register` | Tạo tài khoản + danh mục mặc định; trả 201, chưa đăng nhập |
| POST | `/auth/login` | Đăng nhập |
| GET | `/users/me` | Hồ sơ hiện tại từ DB: id, name, email |
| GET | `/auth/me` | Alias tương thích của `/users/me` |
| POST | `/auth/refresh` | Kiểm tra cookie và cấp access token mới |
| POST | `/auth/logout` | Xóa phiên và cookie; trả 204 |
| GET | `/categories` | Danh mục của tài khoản |
| POST | `/categories` | Tạo danh mục; trả 201 |
| PUT | `/categories/:id` | Sửa danh mục |
| DELETE | `/categories/:id` | Xóa danh mục chưa dùng; trả 204 |
| GET | `/transactions` | Danh sách có phân trang và bộ lọc |
| POST | `/transactions` | Tạo giao dịch; trả 201 |
| PUT | `/transactions/:id` | Sửa giao dịch |
| DELETE | `/transactions/:id` | Xóa giao dịch; trả 204 |
| GET | `/budgets?month=2026-10` | Hạn mức và số đã chi trong tháng |
| PUT | `/budgets` | Tạo/cập nhật hạn mức tháng/danh mục |
| DELETE | `/budgets/:id` | Xóa ngân sách; trả 204 |
| GET | `/reports/summary?month=2026-10` | Tổng hợp tháng, phân bổ khoản chi, xu hướng 6 tháng |

## Request mẫu

Đăng ký:
```json
{"name":"Bùi Đức Hiệp","email":"hiep@example.com","password":"Password123!"}
```
Đăng ký trả `{"message":"Đăng ký thành công."}`. Sau đó gọi login với `email`, `password` (không gửi `name`). Login đặt cookie refresh token và trả JSON:
```json
{"accessToken":"<JWT>","accessTokenExpiresAt":"<ISO timestamp>","user":{"id":"<uuid>","name":"Bùi Đức Hiệp","email":"hiep@example.com"}}
```

Access token hạn 15 phút. Refresh token là chuỗi ngẫu nhiên 64 byte; DB lưu SHA-256 và thời hạn cố định 14 ngày. Chỉ cần `JWT_ACCESS_SECRET`.

Cookie `refreshToken`: HttpOnly, Path=/api/auth, Max-Age=1209600. Production dùng Secure + SameSite=None (HTTPS); local dùng SameSite=Lax, không Secure để chạy HTTP. Web local nên dùng cùng hostname (localhost cho cả API và Flutter, hoặc 127.0.0.1 cho cả hai).

`POST /auth/refresh` gửi cookie, không cần body hoặc access token. Kết quả chỉ gồm `accessToken` và `accessTokenExpiresAt`. Refresh không xoay token, không gia hạn ngày hết hạn và không gửi lại Set-Cookie. Cookie thiếu/sai/hết hạn trả 401. Hai request refresh đồng thời đều có thể thành công.

`POST /auth/logout` gửi cookie, không cần body. Backend xóa session và xóa cookie cùng path/options; gọi lại hoặc không có cookie vẫn trả 204. Access token của session bị xóa không còn dùng được ở các request tiếp theo; phiên khác không bị ảnh hưởng.

Flutter Web để trình duyệt giữ cookie HttpOnly (`withCredentials=true`); Android dùng HTTP client lưu cookie trong secure storage và chỉ gửi tới `/api/auth/*` cùng origin. Access token chỉ giữ trong bộ nhớ; khi mở lại ứng dụng, gọi refresh rồi lấy `/users/me`. Client cũ lưu cặp token JSON cần đăng nhập lại.

Danh mục:
```json
{"name":"Học tập","kind":"expense","color":"#3B82F6"}
```

Giao dịch (POST/PUT cùng schema):
```json
{"categoryId":"<uuid lấy từ GET /categories>","kind":"expense","amount":50000,"occurredOn":"2026-10-12","note":"Ăn trưa","paymentMethod":"cash"}
```
`paymentMethod`: `cash`, `bank`, `other`. `note` tối đa 500 ký tự. API nhận `amount` dạng số nguyên JSON; API trả các giá trị tiền dạng **chuỗi số nguyên** để giữ biểu diễn NUMERIC của PostgreSQL.

Ngân sách:
```json
{"categoryId":"<uuid danh mục expense>","month":"2026-10","amount":2000000}
```

Danh sách giao dịch:
```text
GET /transactions?month=2026-10&kind=expense&search=ăn&page=1&limit=30
```
Tất cả bộ lọc đều không bắt buộc. `page` mặc định 1; `limit` mặc định 30, tối đa 100. Nếu không truyền tháng, API trả mọi tháng. `search` tìm chuỗi con không phân biệt hoa/thường trong ghi chú hoặc tên danh mục. Kết quả `{items: [...], total, page, limit}`.

Thống kê: `{month,income,expense,balance,count,byCategory,trend}`. `balance` là chênh lệch của tháng đã chọn. `trend` luôn có 6 tháng kết thúc ở tháng đã chọn, tháng không có giao dịch là 0. `byCategory` chỉ tổng hợp khoản chi.

## Lỗi

| Status | Ý nghĩa |
|---|---|
| 400 | Dữ liệu sai, danh mục sai chủ sở hữu hoặc sai loại |
| 401 | Chưa đăng nhập, sai thông tin hoặc phiên hết hạn |
| 404 | Không có bản ghi hoặc bản ghi không thuộc tài khoản |
| 409 | Email/tên danh mục trùng, danh mục có dữ liệu tham chiếu |
| 429 | Vượt số yêu cầu cho phép |
| 500 | Lỗi nội bộ; không trả thông tin kỹ thuật nhạy cảm |

Ví dụ: `{"message":"Dữ liệu chưa hợp lệ.","errors":[{"field":"amount","message":"..."}]}`. Các lỗi khác thường chỉ có `message`.
